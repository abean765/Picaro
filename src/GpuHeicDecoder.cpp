#include "GpuHeicDecoder.h"
#include <QDebug>

#ifdef HAVE_FFMPEG_HW

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
#include <libswscale/swscale.h>
}

namespace GpuHeicDecoder {

// Preferred HW device types in order of priority
static const AVHWDeviceType s_hwTypes[] = {
    AV_HWDEVICE_TYPE_CUDA,       // NVIDIA NVDEC
    AV_HWDEVICE_TYPE_VAAPI,      // Intel/AMD on Linux
    AV_HWDEVICE_TYPE_VIDEOTOOLBOX, // macOS
    AV_HWDEVICE_TYPE_NONE        // sentinel
};

struct HwContext {
    AVBufferRef *deviceRef = nullptr;
    AVHWDeviceType type = AV_HWDEVICE_TYPE_NONE;
    AVPixelFormat hwPixFmt = AV_PIX_FMT_NONE;
};

static AVPixelFormat hwPixFmtForType(AVHWDeviceType type)
{
    switch (type) {
    case AV_HWDEVICE_TYPE_CUDA:          return AV_PIX_FMT_CUDA;
    case AV_HWDEVICE_TYPE_VAAPI:         return AV_PIX_FMT_VAAPI;
    case AV_HWDEVICE_TYPE_VIDEOTOOLBOX:  return AV_PIX_FMT_VIDEOTOOLBOX;
    default:                             return AV_PIX_FMT_NONE;
    }
}

// Callback for FFmpeg to select the HW pixel format
static AVPixelFormat getHwFormat(AVCodecContext *ctx, const AVPixelFormat *pixFmts)
{
    auto *hw = static_cast<HwContext *>(ctx->opaque);
    for (const AVPixelFormat *p = pixFmts; *p != AV_PIX_FMT_NONE; ++p) {
        if (*p == hw->hwPixFmt)
            return *p;
    }
    // HW format not offered, fall through to software
    return pixFmts[0];
}

static HwContext initHwDevice()
{
    HwContext hw;
    for (int i = 0; s_hwTypes[i] != AV_HWDEVICE_TYPE_NONE; ++i) {
        int ret = av_hwdevice_ctx_create(&hw.deviceRef, s_hwTypes[i], nullptr, nullptr, 0);
        if (ret == 0) {
            hw.type = s_hwTypes[i];
            hw.hwPixFmt = hwPixFmtForType(s_hwTypes[i]);
            qDebug() << "GPU HEIC decoder: using"
                     << av_hwdevice_get_type_name(s_hwTypes[i]);
            return hw;
        }
    }
    return hw;
}

static QImage frameToQImage(AVFrame *frame, int maxSize)
{
    // If HW frame, transfer to system memory first
    AVFrame *swFrame = nullptr;
    AVFrame *srcFrame = frame;

    if (frame->hw_frames_ctx) {
        swFrame = av_frame_alloc();
        if (av_hwframe_transfer_data(swFrame, frame, 0) < 0) {
            qWarning() << "GPU HEIC: failed to transfer HW frame to system memory";
            av_frame_free(&swFrame);
            return {};
        }
        srcFrame = swFrame;
    }

    // Calculate scaled dimensions
    int srcW = srcFrame->width;
    int srcH = srcFrame->height;
    int dstW, dstH;
    if (srcW >= srcH) {
        dstW = maxSize;
        dstH = maxSize * srcH / srcW;
    } else {
        dstH = maxSize;
        dstW = maxSize * srcW / srcH;
    }
    // Ensure even dimensions for scaler
    dstW = (dstW + 1) & ~1;
    dstH = (dstH + 1) & ~1;

    // Scale to thumbnail size and convert to RGB32
    SwsContext *sws = sws_getContext(
        srcW, srcH, static_cast<AVPixelFormat>(srcFrame->format),
        dstW, dstH, AV_PIX_FMT_RGB32,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws) {
        qWarning() << "GPU HEIC: sws_getContext failed";
        av_frame_free(&swFrame);
        return {};
    }

    QImage result(dstW, dstH, QImage::Format_RGB32);
    uint8_t *dstData[1] = { result.bits() };
    int dstLinesize[1] = { static_cast<int>(result.bytesPerLine()) };

    sws_scale(sws, srcFrame->data, srcFrame->linesize, 0, srcH,
              dstData, dstLinesize);

    sws_freeContext(sws);
    av_frame_free(&swFrame);

    return result;
}

// RAII wrapper to ensure AVBufferRef is freed when the thread exits.
struct ThreadHwContext {
    HwContext hw;
    bool initialized = false;

    ~ThreadHwContext()
    {
        if (hw.deviceRef) {
            av_buffer_unref(&hw.deviceRef);
        }
    }
};

static thread_local ThreadHwContext t_hwCtx;

static HwContext &getThreadHw()
{
    if (!t_hwCtx.initialized) {
        t_hwCtx.hw = initHwDevice();
        t_hwCtx.initialized = true;
    }
    return t_hwCtx.hw;
}

QImage decodeThumbnail(const QString &filePath, int maxSize)
{
    HwContext &hw = getThreadHw();

    // Open the HEIC file via FFmpeg (libavformat handles ISOBMFF/HEIF container)
    AVFormatContext *fmtCtx = nullptr;
    if (avformat_open_input(&fmtCtx, filePath.toUtf8().constData(),
                            nullptr, nullptr) < 0) {
        return {};
    }

    if (avformat_find_stream_info(fmtCtx, nullptr) < 0) {
        avformat_close_input(&fmtCtx);
        return {};
    }

    // Find the HEVC video stream (HEIC images appear as single-frame video)
    int streamIdx = -1;
    for (unsigned i = 0; i < fmtCtx->nb_streams; ++i) {
        if (fmtCtx->streams[i]->codecpar->codec_id == AV_CODEC_ID_HEVC) {
            streamIdx = static_cast<int>(i);
            break;
        }
    }
    if (streamIdx < 0) {
        avformat_close_input(&fmtCtx);
        return {};
    }

    AVCodecParameters *codecPar = fmtCtx->streams[streamIdx]->codecpar;

    // Find decoder — prefer HW-capable
    const AVCodec *codec = avcodec_find_decoder(codecPar->codec_id);
    if (!codec) {
        avformat_close_input(&fmtCtx);
        return {};
    }

    AVCodecContext *codecCtx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(codecCtx, codecPar);

    // Attach HW device context if available
    if (hw.deviceRef) {
        codecCtx->hw_device_ctx = av_buffer_ref(hw.deviceRef);
        codecCtx->opaque = &hw;
        codecCtx->get_format = getHwFormat;
    }

    if (avcodec_open2(codecCtx, codec, nullptr) < 0) {
        avcodec_free_context(&codecCtx);
        avformat_close_input(&fmtCtx);
        return {};
    }

    // Read one frame (HEIC = single frame)
    QImage result;
    AVPacket *pkt = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();

    while (av_read_frame(fmtCtx, pkt) >= 0) {
        if (pkt->stream_index != streamIdx) {
            av_packet_unref(pkt);
            continue;
        }

        if (avcodec_send_packet(codecCtx, pkt) == 0) {
            if (avcodec_receive_frame(codecCtx, frame) == 0) {
                result = frameToQImage(frame, maxSize);
            }
        }
        av_packet_unref(pkt);
        break; // Only need first frame
    }

    av_frame_free(&frame);
    av_packet_free(&pkt);
    avcodec_free_context(&codecCtx);
    avformat_close_input(&fmtCtx);

    return result;
}

bool isAvailable()
{
    // Check if FFmpeg can find any HW device
    HwContext &hw = getThreadHw();
    return hw.deviceRef != nullptr;
}

} // namespace GpuHeicDecoder

#else // !HAVE_FFMPEG_HW

namespace GpuHeicDecoder {

QImage decodeThumbnail(const QString &filePath, int maxSize)
{
    Q_UNUSED(filePath);
    Q_UNUSED(maxSize);
    return {};
}

bool isAvailable()
{
    return false;
}

} // namespace GpuHeicDecoder

#endif // HAVE_FFMPEG_HW
