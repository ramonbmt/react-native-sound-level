package com.punarinta.RNSoundLevel;

import android.content.Context;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableArray;

import java.util.Timer;
import java.util.TimerTask;

import android.media.MediaRecorder;
import android.util.Log;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import android.media.AudioFormat;
import android.media.AudioRecord;

import com.punarinta.fft.RealDoubleFFT;

class RNSoundLevelModule extends ReactContextBaseJavaModule {

  private static final String TAG = "RNSoundLevel";

  private Context context;
  private MediaRecorder recorder;
  private boolean isRecording = false;
  private Timer timer;
  private int frameId = 0;

  private AudioRecord recordAudio;
  private int minBytes;
  private int sampleRate = 44100;
  private int fftBins = 22;
  private final static int AGC_OFF = MediaRecorder.AudioSource.VOICE_RECOGNITION;
  private final static float MEAN_MAX = 16384f;

  public RNSoundLevelModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.context = reactContext;
  }

  @Override
  public String getName() {
    return "RNSoundLevelModule";
  }

  @ReactMethod
  public void start(Promise promise) {
    if (isRecording) {
      logAndRejectPromise(promise, "INVALID_STATE", "Please call stop before starting");
      return;
    }

    // recorder = new MediaRecorder();
    // try {
    //   recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
    //   recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
    //   recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
    //   recorder.setAudioSamplingRate(22050);
    //   recorder.setAudioChannels(1);
    //   recorder.setAudioEncodingBitRate(32000);
    //   recorder.setOutputFile(this.getReactApplicationContext().getCacheDir().getAbsolutePath() + "/soundlevel");
    // }
    // catch(final Exception e) {
    //   logAndRejectPromise(promise, "COULDNT_CONFIGURE_MEDIA_RECORDER" , "Make sure you've added RECORD_AUDIO permission to your AndroidManifest.xml file " + e.getMessage());
    //   return;
    // }

    try {
      minBytes = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO,
          AudioFormat.ENCODING_PCM_16BIT);
      minBytes = Math.max(minBytes, fftBins);
      // VOICE_RECOGNITION: use the mic with AGC turned off!
      recordAudio =  new AudioRecord(AGC_OFF, sampleRate,
          AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT,  minBytes);
      Log.d(TAG, "Buffer size: " + minBytes + " (" + recordAudio.getSampleRate() + "=" + sampleRate + ")");
    } catch(final Exception e) {
      logAndRejectPromise(promise, "COULDNT_CONFIGURE_MEDIA_RECORDER" , "2 version Make sure you've added RECORD_AUDIO permission to your AndroidManifest.xml file " + e.getMessage());
      return;
    }

    // try {
    //   recorder.prepare();
    // } catch (final Exception e) {
    //   logAndRejectPromise(promise, "COULDNT_PREPARE_RECORDING", e.getMessage());
    // }

    // recorder.start();

    recordAudio.startRecording();

    frameId = 0;
    isRecording = true;
    startTimer();
    promise.resolve(true);
  }

  @ReactMethod
  public void stop(Promise promise) {
    if (!isRecording) {
      logAndRejectPromise(promise, "INVALID_STATE", "Please call start before stopping recording");
      return;
    }

    stopTimer();
    isRecording = false;

    try {
      // recorder.stop();
      // recorder.release();

      recordAudio.stop();
      recordAudio.release();
      
    }
    catch (final RuntimeException e) {
      logAndRejectPromise(promise, "RUNTIME_EXCEPTION", "No valid audio data received. You may be using a device that can't record audio.");
      return;
    }
    finally {
      // recorder = null;

      recordAudio = null;
    }

    promise.resolve(true);
  }

    /**
   * Convert our samples to double for fft.
   */
  private static double[] shortToDouble(short[] s, double[] d) {
    for (int i = 0; i < d.length; i++) {
      d[i] = s[i];
    }
    return d;
  }

  /**
   * Convert our samples to double for fft.
   */
  private static int[] doubleToInt(double[] s, int[] d) {
    // for (int i = 0; i < d.length; i++) {
    //   d[i] = s[i];
    // }
    // return d;
    for (int i=0; i < s.length; i++) {
      d[i] = (int) s[i];
    }
    return d;
  }

  /**
   * Compute db of bin, where "max" is the reference db
   * @param r Real part
   * @param i complex part
   */
  private static double db2(double r, double i, double maxSquared) {
    return 5.0 * Math.log10((r * r + i * i) / maxSquared);
  }

  /**
   * Convert the fft output to DB
   */

  static double[] convertToDb(double[] data, double maxSquared) {
    data[0] = db2(data[0], 0.0, maxSquared);
    int j = 1;
    for (int i=1; i < data.length - 1; i+=2, j++) {
      data[j] = db2(data[i], data[i+1], maxSquared);
    }
    data[j] = data[0];
    return data;
  }

  private void startTimer() {
    timer = new Timer();

    

    timer.scheduleAtFixedRate(new TimerTask() {
      @Override
      public void run() {
        short[] audioSamples = new short[minBytes];
        final double[] fftData = new double[fftBins];
        final int[] fftDataInt = new int[fftBins];
        RealDoubleFFT fft = new RealDoubleFFT(fftBins);
        double scale = MEAN_MAX * MEAN_MAX * fftBins * fftBins / 2d;

        WritableMap body = Arguments.createMap();
        WritableArray frec = Arguments.createArray();
        body.putDouble("id", frameId++);

        // int amplitude = recorder.getMaxAmplitude();
        // if (amplitude == 0) {
        //   body.putInt("value", -160);
        //   body.putInt("rawValue", 0);
        //   body.putInt("decibel", 0);
        // } else {
        //   body.putInt("rawValue", amplitude);
        //   body.putInt("value", (int) (20 * Math.log(((double) amplitude) / 32767d)));
        //   body.putInt("decibel", (int) (20 * Math.log(((double) amplitude) / 32767d)));
        // }

        recordAudio.read(audioSamples, 0, minBytes);
        shortToDouble(audioSamples, fftData);
        fft.ft(fftData);
        convertToDb(fftData, scale);
        doubleToInt(fftData, fftDataInt);
        Log.d(TAG, "size: " + fftData.length);
        for (int i=1; i < fftData.length; i++) {
          Log.d(TAG, "data-" + i + ":" + fftData[i]);
          frec.pushDouble(fftData[i]);
          // data[j] = db2(data[i], data[i+1], maxSquared);
        }

        body.putInt("maxFrec", 0);
        body.putArray("meanFrec", frec);
        body.putInt("value", -160);
        body.putInt("rawValue", 0);
        body.putInt("decibel", 0);

        sendEvent("frame", body);
      }
    }, 0, 250);
  }

  private void stopTimer() {
    if (timer != null) {
      timer.cancel();
      timer.purge();
      timer = null;
    }
  }

  private void sendEvent(String eventName, Object params) {
    getReactApplicationContext()
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(eventName, params);
  }

  private void logAndRejectPromise(Promise promise, String errorCode, String errorMessage) {
    Log.e(TAG, errorMessage);
    promise.reject(errorCode, errorMessage);
  }
}
