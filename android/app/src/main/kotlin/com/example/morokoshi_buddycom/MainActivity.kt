package com.example.morokoshi_buddycom

import android.Manifest
import android.content.pm.PackageManager
import android.media.*
import android.media.AudioTrack.WRITE_BLOCKING
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlin.math.max

class MainActivity : FlutterActivity() {
    companion object {
        private const val samplingRate = 44100

        // フレームレート (fps)
        // 1秒間に何回音声データを処理したいか
        // 各自好きに決める
        private const val frameRate = 10

        // 1フレームの音声データ(=Short値)の数
        private const val oneFrameDataCount = 1024

        // 1フレームの音声データのバイト数 (byte)
        // Byte = 8 bit, Short = 16 bit なので, Shortの倍になる
        private const val oneFrameSizeInByte = oneFrameDataCount

        private const val encoding = AudioFormat.ENCODING_PCM_FLOAT

        // 音声データのバッファサイズ (byte)
        // 要件1:oneFrameSizeInByte より大きくする必要がある
        // 要件2:デバイスの要求する最小値より大きくする必要がある
        private val audioBufferSizeInByte =
            max(
                oneFrameSizeInByte * 10, // 適当に10フレーム分のバッファを持たせた
                AudioRecord.getMinBufferSize(
                    samplingRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    encoding
                )
            )
    }

    private lateinit var morokoshiAudioTrack: MorokoshiAudioTrack

    inner class MorokoshiAudioTrack {
        private val audioTrack: AudioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(encoding)
                    .setSampleRate(samplingRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_DEFAULT)
                    .build()
            )
            .setBufferSizeInBytes(audioBufferSizeInByte)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        fun ready(/* arr: ByteArray */) {
            stop()

            /* //バッファを埋めておく
            val loopCount = audioBufferSizeInByte / arr.count()
            for (i in 0 until loopCount) {
                audioTrack.write(arr, 0, arr.count(), WRITE_BLOCKING)
            } */
        }

        //再生
        fun play(arr: FloatArray) {
            //再生バッファにデータを書き込む
            audioTrack.write(arr, 0, arr.count(), WRITE_BLOCKING)

            //1回分の再生終了を検知して停止する
            audioTrack.setPlaybackPositionUpdateListener(
                object : AudioTrack.OnPlaybackPositionUpdateListener {
                    override fun onPeriodicNotification(track: AudioTrack) {
                    }

                    override fun onMarkerReached(track: AudioTrack) {
                        //再生完了
                        if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                            //停止
                            track.stop()
                        }
                    }
                }
            )

            //再生終了検知するためのNotificationをセット
            audioTrack.notificationMarkerPosition = arr.count()

            //再生状態にする
            if (audioTrack.playState != AudioTrack.PLAYSTATE_PLAYING) {
                audioTrack.play()
            }

        }

        //停止
        fun stop() {
            if (audioTrack.playState == AudioTrack.PLAYSTATE_PLAYING) {
                //再生中の場合は止める
                audioTrack.stop()
                //再生バッファをクリアする
                audioTrack.flush()
            }
        }

        //終了時にオブジェクトを破棄する
        fun release() {
            try {
                audioTrack.stop()
                audioTrack.release()
                // Logger.set(LogKind.INFO, "sound released")
            } catch (e: Exception) {
                // Logger.set(LogKind.ERROR, e.toString())
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 0)
        morokoshiAudioTrack = MorokoshiAudioTrack()
        morokoshiAudioTrack.ready()
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            // TODO: Consider calling
            //    ActivityCompat#requestPermissions
            // here to request the missing permissions, and then overriding
            //   public void onRequestPermissionsResult(int requestCode, String[] permissions,
            //                                          int[] grantResults)
            // to handle the case where the user grants the permission. See the documentation
            // for ActivityCompat#requestPermissions for more details.
            return
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.morokoshi.audio.recorder"
        ).setStreamHandler(
            object : StreamHandler {
                private lateinit var audioRecord: AudioRecord
                override fun onListen(arguments: Any?, eventSink: EventSink) {
                    Log.d("Android", "EventChannel onListen called")
                    /* Handler().postDelayed({
                        eventSink.success("Android")
                        //eventSink?.endOfStream()
                        //eventSink?.error("error code", "error message","error details")
                    }, 500) */
                    /* val mediaRecorder = MediaRecorder()
                    mediaRecorder.setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                    mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_2_TS) */


                    if (ActivityCompat.checkSelfPermission(
                            this@MainActivity,
                            Manifest.permission.RECORD_AUDIO
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        // TODO: Consider calling
                        //    ActivityCompat#requestPermissions
                        // here to request the missing permissions, and then overriding
                        //   public void onRequestPermissionsResult(int requestCode, String[] permissions,
                        //                                          int[] grantResults)
                        // to handle the case where the user grants the permission. See the documentation
                        // for ActivityCompat#requestPermissions for more details.
                        return
                    }
                    try {
                        audioRecord = AudioRecord(
                            MediaRecorder.AudioSource.VOICE_COMMUNICATION, // 音声のソース
                            samplingRate, // サンプリングレート
                            AudioFormat.CHANNEL_IN_MONO, // チャネル設定. MONO and STEREO が全デバイスサポート保障
                            encoding, // PCM16が全デバイスサポート保障
                            audioBufferSizeInByte // バッファ
                        )
                    } catch (e: Exception) {
                        eventSink.error("a", "Exception: " + e.message, e)
                        return
                    }

                    audioRecord.apply {

                        // 音声データを幾つずつ処理するか( = 1フレームのデータの数)
                        positionNotificationPeriod = oneFrameDataCount

                        // ここで指定した数になったタイミングで, 後続の onMarkerReached が呼び出される
                        // 通常のストリーミング処理では必要なさそう？
                        // notificationMarkerPosition = 40000 // 使わないなら設定しない.

                        // 音声データを格納する配列
                        val audioDataArray = FloatArray(oneFrameDataCount)
                        setRecordPositionUpdateListener(object :
                            AudioRecord.OnRecordPositionUpdateListener {

                            // フレームごとの処理
                            override fun onPeriodicNotification(recorder: AudioRecord) {
                                if (recorder.state == AudioRecord.STATE_INITIALIZED) {
                                    recorder.read(
                                        audioDataArray,
                                        0,
                                        oneFrameDataCount,
                                        AudioRecord.READ_BLOCKING
                                    ) // 音声データ読込
                                    Log.v(
                                        "AudioRecord",
                                        "onPeriodicNotification size=${audioDataArray.size}"
                                    )
                                    eventSink.success(audioDataArray)
                                }
                                // 好きに処理する
                            }

                            // マーカータイミングの処理.
                            // notificationMarkerPosition に到達した際に呼ばれる
                            override fun onMarkerReached(recorder: AudioRecord) {
                                if (recorder.state == AudioRecord.STATE_INITIALIZED) {
                                    recorder.read(
                                        audioDataArray,
                                        0,
                                        oneFrameDataCount,
                                        AudioRecord.READ_BLOCKING
                                    ) // 音声データ読込
                                    Log.v(
                                        "AudioRecord",
                                        "onPeriodicNotification size=${audioDataArray.size}"
                                    )
                                    eventSink.success(audioDataArray)
                                }
                            }
                        })
                        startRecording()
                    }

                }

                override fun onCancel(arguments: Any?) {
                    Log.d("Android", "EventChannel onCancel called")
                    audioRecord.apply {
                        stop()
                        release()

                    }
                }
            }
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.morokoshi.audio.player"
        ).setMethodCallHandler { methodCall, result ->
            when (methodCall.method) {
                "ready" -> {
                    morokoshiAudioTrack = MorokoshiAudioTrack()
                    result.success(null)
                }
                "play" -> {
                    val byte: FloatArray? = methodCall.argument("byte")
                    if (byte == null) {
                        result.error("", "argument byte is null or unset", null)
                    } else {
                        // morokoshiAudioTrack.ready(byte)
                        try {
                            morokoshiAudioTrack.play(byte)
                            result.success(null)
                        } catch (e: Error) {
                            result.error("", e.message, null)
                        }
                    }
                }
                "stop" -> {
                    morokoshiAudioTrack.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        morokoshiAudioTrack.release()
    }
}
