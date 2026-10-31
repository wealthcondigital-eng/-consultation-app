package consult.nesliferesearch.com

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Mixes and shrinks a recorded consultation on the phone, with Media3
 * Transformer.
 *
 * `consult/recording` (methods):
 *  - `compose` `{inputs: [path], hasVideo, output, maxHeight, videoBitrate,
 *    audioBitrate}` → `{ok, sizeBytes, durationMs}` or `{ok: false, error}`
 *
 * Each input is its own [EditedMediaItemSequence], so the sequences play
 * *together* and their audio is mixed — the doctor's voice from one file and
 * the patient's from the other. Only the first input's picture is kept, scaled
 * to `maxHeight` and re-encoded as H.264; with no video the output is AAC in
 * MPEG-4 (`.m4a`).
 *
 * Answers through the result rather than throwing: the Dart side keeps the raw
 * file when this fails, and needs to know that it failed, not why the channel
 * broke.
 */
@UnstableApi
class RecordingComposer(private val context: Context, messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "consult/recording").setMethodCallHandler { call, result ->
            when (call.method) {
                "compose" -> compose(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun compose(call: MethodCall, result: MethodChannel.Result) {
        val inputs = call.argument<List<String>>("inputs").orEmpty()
            .filter { File(it).let { file -> file.exists() && file.length() > 0 } }
        val output = call.argument<String>("output")
        val hasVideo = call.argument<Boolean>("hasVideo") ?: false
        val maxHeight = call.argument<Int>("maxHeight") ?: 360
        val videoBitrate = call.argument<Int>("videoBitrate") ?: 600_000
        val audioBitrate = call.argument<Int>("audioBitrate") ?: 64_000

        if (inputs.isEmpty() || output == null) {
            result.success(mapOf("ok" to false, "error" to "Nothing to compose"))
            return
        }

        // Transformer reports on the thread that started it, which must have a
        // Looper. The main thread does, and the work itself runs on Media3's
        // own threads, so nothing here blocks the UI.
        main.post {
            try {
                start(inputs, output, hasVideo, maxHeight, videoBitrate, audioBitrate, result)
            } catch (error: Exception) {
                Log.w(TAG, "Compose could not start", error)
                result.success(mapOf("ok" to false, "error" to (error.message ?: error.toString())))
            }
        }
    }

    private fun start(
        inputs: List<String>,
        output: String,
        hasVideo: Boolean,
        maxHeight: Int,
        videoBitrate: Int,
        audioBitrate: Int,
        result: MethodChannel.Result,
    ) {
        val outputFile = File(output)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) outputFile.delete()

        val sequences = inputs.mapIndexed { index, path ->
            val keepVideo = hasVideo && index == 0
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
                .setRemoveVideo(!keepVideo)
                .apply {
                    if (keepVideo) {
                        setEffects(Effects(listOf(), listOf(Presentation.createForHeight(maxHeight))))
                    }
                }
                .build()
            // Track types stated per sequence: the picture comes from the
            // first, voice from every one of them.
            if (keepVideo) {
                EditedMediaItemSequence.withAudioAndVideoFrom(listOf(item))
            } else {
                EditedMediaItemSequence.withAudioFrom(listOf(item))
            }
        }

        val composition = Composition.Builder(sequences).build()

        val encoders = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder().setBitrate(videoBitrate).build()
            )
            .setRequestedAudioEncoderSettings(
                AudioEncoderSettings.Builder().setBitrate(audioBitrate).build()
            )
            // A phone that cannot encode exactly 360p at this bitrate picks the
            // nearest it can, rather than refusing the whole export.
            .setEnableFallback(true)
            .build()

        var answered = false
        fun answer(value: Map<String, Any?>) {
            if (answered) return
            answered = true
            result.success(value)
        }

        val transformer = Transformer.Builder(context)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .apply { if (hasVideo) setVideoMimeType(MimeTypes.VIDEO_H264) }
            .setEncoderFactory(encoders)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    answer(
                        mapOf(
                            "ok" to true,
                            "sizeBytes" to outputFile.length(),
                            "durationMs" to exportResult.approximateDurationMs,
                        )
                    )
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    Log.w(TAG, "Compose failed", exportException)
                    outputFile.delete()
                    answer(
                        mapOf(
                            "ok" to false,
                            "error" to (exportException.message ?: exportException.errorCodeName),
                        )
                    )
                }
            })
            .build()

        transformer.start(composition, output)
    }

    private companion object {
        const val TAG = "RecordingComposer"
    }
}
