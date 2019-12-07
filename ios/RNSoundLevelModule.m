//
//  RNSoundLevelModule.h
//  RNSoundLevelModule
//
//  Created by Vladimir Osipov on 2018-07-09.
//  Copyright (c) 2018 Vladimir Osipov. All rights reserved.
//

#import "RNSoundLevelModule.h"
#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import "FFTHelper.h"
//#import "baseApp2-Swift.h"

@implementation RNSoundLevelModule {
  AVAudioRecorder *_audioRecorder;
  id _progressUpdateTimer;
  int _frameId;
  int _progressUpdateInterval;
  NSDate *_prevProgressUpdateTime;
  AVAudioSession *_recordSession;
  AudioUnit remoteIOUnit;
  //AudioComponentInstance remoteIOUnit;
  //AudioUnit tempAudioUnit;
  float sampleRate;
}

@synthesize bridge = _bridge;

static OSStatus CheckError(OSStatus error, const char *operation)
{
  if (error == noErr) {
    return error;
  }
  char errorString[20];
  // See if it appears to be a 4-char-code
  *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
  if (isprint(errorString[1]) && isprint(errorString[2]) &&
      isprint(errorString[3]) && isprint(errorString[4])) {
    errorString[0] = errorString[5] = '\'';
    errorString[6] = '\0';
  } else {
    // No, format it as an integer
    sprintf(errorString, "%d", (int)error);
  }
  fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
  return error;
}

Float32 *windowBuffer= NULL;

static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    NSLog(@"Start Monitoring7");
  OSStatus status;
  
  //NSLog(@"ioData %p", ioData);
    
  RNSoundLevelModule *audioController = (__bridge RNSoundLevelModule *) inRefCon;
  

  int channelCount = 1;

  // build the AudioBufferList structure
  AudioBufferList *bufferList = (AudioBufferList *) malloc (sizeof (AudioBufferList));
  bufferList->mNumberBuffers = channelCount;
  bufferList->mBuffers[0].mNumberChannels = 1;
  bufferList->mBuffers[0].mDataByteSize = inNumberFrames * 2;
  bufferList->mBuffers[0].mData = NULL;

  // get the recorded samples
  status = AudioUnitRender(audioController->remoteIOUnit,
                           ioActionFlags,
                           inTimeStamp,
                           inBusNumber,
                           inNumberFrames,
                           bufferList);
  if (status != noErr) {
    return status;
  }
    
    #define DBOFFSET -74.0
            // DBOFFSET is An offset that will be used to normalize
                    // the decibels to a maximum of zero.
            // This is an estimate, you can do your own or construct
                    // an experiment to find the right value
    #define LOWPASSFILTERTIMESLICE .001
            // LOWPASSFILTERTIMESLICE is part of the low pass filter
                    // and should be a small positive value

            SInt16* samples = (SInt16*)(bufferList->mBuffers[0].mData); // Step 1: get an array of
                    // your samples that you can loop through. Each sample contains the amplitude.

            Float32 decibels = DBOFFSET; // When we have no signal we'll leave this on the lowest setting
            Float32 currentFilteredValueOfSampleAmplitude, previousFilteredValueOfSampleAmplitude; // We'll need
                                                                                         // these in the low-pass filter
            
                    Float32 peakValue = DBOFFSET; // We'll end up storing the peak value here

            for (int i=0; i < inNumberFrames; i++) {

                Float32 absoluteValueOfSampleAmplitude = abs(samples[i]); //Step 2: for each sample,
                                                                          // get its amplitude's absolute value.

                // Step 3: for each sample's absolute value, run it through a simple low-pass filter
                // Begin low-pass filter
                currentFilteredValueOfSampleAmplitude = LOWPASSFILTERTIMESLICE * absoluteValueOfSampleAmplitude + (1.0 - LOWPASSFILTERTIMESLICE) * previousFilteredValueOfSampleAmplitude;
                previousFilteredValueOfSampleAmplitude = currentFilteredValueOfSampleAmplitude;
                Float32 amplitudeToConvertToDB = currentFilteredValueOfSampleAmplitude;
                // End low-pass filter

                Float32 sampleDB = 20.0*log10(amplitudeToConvertToDB) + DBOFFSET;
                // Step 4: for each sample's filtered absolute value, convert it into decibels
                // Step 5: for each sample's filtered absolute value in decibels,
                            // add an offset value that normalizes the clipping point of the device to zero.

                if((sampleDB == sampleDB) && (sampleDB != -DBL_MAX)) { // if it's a rational number and
                                                                                           // isn't infinite
                    if(sampleDB > peakValue) peakValue = sampleDB; // Step 6: keep the highest value
                                                                                      // you find.
                    decibels = peakValue; // final value
                }
            }

            NSLog(@"decibel level is %f", decibels);

    NSData *data = [[NSData alloc] initWithBytes:bufferList->mBuffers[0].mData
                                        length:bufferList->mBuffers[0].mDataByteSize];
    NSLog(@"data: %@", data);
    
    //[float] monoSamples;
    //float monoSamples;
    //[data getBytes:&monoSamples length:sizeof(float)];
    //float analysisBuffer;
    //[data getBytes:&analysisBuffer length:sizeof(float)];
    //SInt32* monoSamples2 = (SInt32*)(bufferList->mBuffers[0].mData);
    //Float32 factor = (Float32)(1 << 24);
    //Float32 * monoSamples = (Float32*) malloc(sizeof(Float32)*inNumberFrames);
    //for( UInt32 i = 0; i < inNumberFrames; i++ ){
        // convert (AU is by default 8.24 fixed)
        //buffy[2*i] = ((Float32)monoSamples2[i]) / factor;
      //monoSamples[i] = (Float32)monoSamples2[i];
    //}
    //Float32 * monoSamples = (Float32 *)bufferList->mBuffers[0].mData;
  
    //if (windowBuffer==NULL) { windowBuffer = (Float32*) malloc(sizeof(Float32)*inNumberFrames); }
    //vDSP_blkman_window(windowBuffer, inNumberFrames, 0);
    //vDSP_vmul(monoSamples, 1, windowBuffer, 1, monoSamples, 1, inNumberFrames);
    //FFTHelperRef *fftConverter = NULL;
    //fftConverter = FFTHelperCreate(inNumberFrames);
    //Float32 *fftData = computeFFT(fftConverter, monoSamples, inNumberFrames);
  
    //NSLog(@"fft datos: %lu", sizeof(fftData)/sizeof(float));
    //for(int i = 0; i < inNumberFrames/2; i++){
      //NSLog(@"fft: %f", fftData[i]);
      //fftData[i];
      //NSLog(@"fft: %f", fftData[i]);
    //}
  
    
    
    //TempiFFT *fft = TempiFFT(inNumberFrames, 44100.0);
    //let fft = TempiFFT(withSize: numberOfFrames, sampleRate: 44100.0)
    //fft.windowType = TempiFFTWindowType.hanning
    //fft.fftForward(samples)
  
    //UInt32 windowLength = inNumberFrames;
    //if (windowBuffer==NULL) { windowBuffer = (Float32*) malloc(sizeof(Float32)*windowLength); }
    //vDSP_hann_window(windowBuffer, inNumberFrames, vDSP_HANN_NORM);
    //vDSP_vmul(&monoSamples, 1, windowBuffer, 1, &analysisBuffer, 1, inNumberFrames);
  
    //float * monoSamples = (float *)(bufferList->mBuffers[0].mData);
    float* monoSamples = (float*) malloc(sizeof(float)*inNumberFrames);
    for (int i=0; i < inNumberFrames; i++) {
        monoSamples[i] = (float)samples[i];
    }
  
    FFTHelper* _fftHelper = [[FFTHelper alloc] initWithFFTSize:inNumberFrames andWindow:WindowTypeHann];
  
    const unsigned long lenMagBuffer = _fftHelper.fftSizeOver2;
    float *fftMagnitudeBuffer = (float *)calloc(lenMagBuffer,sizeof(float));
    
    // take FFT
    [_fftHelper performForwardFFTWithData:monoSamples
                 andCopydBMagnitudeToBuffer:fftMagnitudeBuffer];
  
    NSMutableArray *myArrayOriginal = [[NSMutableArray alloc] init];
    int maxIndex = 0;
    for(int i = 0; i < lenMagBuffer; i++){
      NSNumber *number = [[NSNumber alloc] initWithFloat:fftMagnitudeBuffer[i]];
      [myArrayOriginal addObject:number];
      if(fftMagnitudeBuffer[maxIndex] < fftMagnitudeBuffer[i]){
        maxIndex = i;
      }
    }
  
    //Float32 * frecuencies = (Float32 *)fftMagnitudeBuffer;
    NSLog(@"total bands %lu", lenMagBuffer);
    NSLog(@"maz frecuency %d", maxIndex);
  
    int bandNumber = 22;
    float mean = 0;
    float* meanFrecuency = (float*) malloc(sizeof(float)*bandNumber);
    float ratio = lenMagBuffer / bandNumber;
    NSMutableArray *myArray = [[NSMutableArray alloc] init];
    for(int i = 0; i < bandNumber; i++){
      int startIdx = (int)(floorf((float)i * ratio));
      int stopIdx = (int)(floorf((float)(i + 1) * ratio));
      vDSP_meanv(fftMagnitudeBuffer + startIdx, 1, &mean, (int)(stopIdx - startIdx));
      meanFrecuency[i] = mean;
      NSLog(@"dataFrec: %f", meanFrecuency[i]);
      NSNumber *number = [[NSNumber alloc] initWithFloat:meanFrecuency[i]];
      [myArray addObject:number];
      //[number release];
    }
    NSData *dataMenFrec = [[NSData alloc] initWithBytes:meanFrecuency
                                        length:lenMagBuffer];
    NSLog(@"dataMenFrec: %@", dataMenFrec);
  
  
    //for (int i=0; i < lenMagBuffer; i++) {
      //NSLog(@"dataFrec: %f", fftMagnitudeBuffer[i]);
      //NSLog(@"dataFrec1: %d", samples[1]);
      //NSLog(@"dataFrec2: %f", fftMagnitudeBuffer[i]);
      //NSLog(@"dataFrec3: %f", monoSamples[1]);
    //}
    
    
    
    
    if (audioController->_prevProgressUpdateTime == nil ||
     (([audioController->_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= audioController->_progressUpdateInterval)) {
        audioController->_frameId++;
        NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
        [body setObject:[NSNumber numberWithFloat:audioController->_frameId] forKey:@"id"];
        [body setObject:[NSNumber numberWithFloat:decibels] forKey:@"decibel"];
        [body setObject:myArray forKey:@"meanFrec"];
        [body setObject:myArrayOriginal forKey:@"Frec"];
        [body setObject:[NSNumber numberWithInt:maxIndex] forKey:@"maxFrec"];
        
        //[body setObject:[NSKeyedUnarchiver unarchiveObjectWithData:data] forKey:@"data"];

        [audioController.bridge.eventDispatcher sendAppEventWithName:@"frame" body:body];

      audioController->_prevProgressUpdateTime = [NSDate date];
    }
    
    for (UInt32 i=0; i < bufferList->mNumberBuffers; i++) { // This is only if you need to silence
                                                                // the output of the audio unit
        memset(bufferList->mBuffers[i].mData, 0, bufferList->mBuffers[i].mDataByteSize); // Delete if you
                                                                              // need audio output as well as input
    }

  return noErr;
}

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
  OSStatus status = noErr;

  // Notes: ioData contains buffers (may be more than one!)
  // Fill them up as much as you can. Remember to set the size value in each buffer to match how
  // much data is in the buffer.
    RNSoundLevelModule *audioController = (__bridge RNSoundLevelModule *) inRefCon;
  //AudioController *audioController = (__bridge AudioController *) inRefCon;

  UInt32 bus1 = 1;
  status = AudioUnitRender(audioController->remoteIOUnit,
                           ioActionFlags,
                           inTimeStamp,
                           bus1,
                           inNumberFrames,
                           ioData);
  CheckError(status, "Couldn't render from RemoteIO unit");
  return status;
}

RCT_EXPORT_MODULE();

- (void)sendProgressUpdate {
  if (!_audioRecorder || !_audioRecorder.isRecording) {
    return;
  }

  if (_prevProgressUpdateTime == nil ||
   (([_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= _progressUpdateInterval)) {
      _frameId++;
      NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
      [body setObject:[NSNumber numberWithFloat:_frameId] forKey:@"id"];

      [_audioRecorder updateMeters];
      float _currentLevel = [_audioRecorder averagePowerForChannel: 0];
      [body setObject:[NSNumber numberWithFloat:_currentLevel] forKey:@"value"];
      [body setObject:[NSNumber numberWithFloat:_currentLevel] forKey:@"rawValue"];

      [self.bridge.eventDispatcher sendAppEventWithName:@"frame" body:body];

    _prevProgressUpdateTime = [NSDate date];
  }
}

- (void)stopProgressTimer {
  [_progressUpdateTimer invalidate];
}

- (void)startProgressTimer:(int)monitorInterval {
  _progressUpdateInterval = monitorInterval;

  [self stopProgressTimer];

  _progressUpdateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(sendProgressUpdate)];
  [_progressUpdateTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

RCT_EXPORT_METHOD(start:(int)monitorInterval)
{
  NSLog(@"Start Monitoring");
  _prevProgressUpdateTime = nil;
  [self stopProgressTimer];
    sampleRate = 44100.0;

  NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithInt:AVAudioQualityLow], AVEncoderAudioQualityKey,
          [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
          [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
          [NSNumber numberWithFloat:sampleRate], AVSampleRateKey,
          nil];

  NSError *error = nil;

  _recordSession = [AVAudioSession sharedInstance];
  [_recordSession setCategory:AVAudioSessionCategoryMultiRoute error:nil];
    
    // nuevo
    OSStatus status = noErr;
    
    AudioComponentDescription audioComponentDescription;
    audioComponentDescription.componentType = kAudioUnitType_Output;
    audioComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    audioComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescription.componentFlags = 0;
    audioComponentDescription.componentFlagsMask = 0;
    
    NSLog(@"Start Monitoring1");
    
    AudioComponent remoteIOComponent = AudioComponentFindNext(NULL,&audioComponentDescription);
    status = AudioComponentInstanceNew(remoteIOComponent,&(self->remoteIOUnit));
    
    NSLog(@"Start Monitoring2");
    
    UInt32 oneFlag = 1;
    AudioUnitElement bus0 = 0;
    AudioUnitElement bus1 = 1;

    if ((NO)) {
      // Configure the RemoteIO unit for playback
      status = AudioUnitSetProperty (self->remoteIOUnit,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Output,
                                     bus0,
                                     &oneFlag,
                                     sizeof(oneFlag));
      if (CheckError(status, "Couldn't enable RemoteIO output")) {
          NSLog(@"error: %s", "Couldn't enable RemoteIO output");
      }
    }

    // Configure the RemoteIO unit for input
    status = AudioUnitSetProperty(self->remoteIOUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  bus1,
                                  &oneFlag,
                                  sizeof(oneFlag));
    if (CheckError(status, "Couldn't enable RemoteIO input")) {
        NSLog(@"error: %s", "Couldn't enable RemoteIO input");
    }
    
    NSLog(@"Start Monitoring3");
    
    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mSampleRate = sampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    //asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    //asbd.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    //asbd.mBytesPerPacket = 4;
    //asbd.mFramesPerPacket = 1;
    //asbd.mBytesPerFrame = 4;
    //asbd.mChannelsPerFrame = 2;
    //asbd.mBitsPerChannel = 4 * 8;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd.mBytesPerPacket = 2;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 2;
    asbd.mChannelsPerFrame = 1;
    asbd.mBitsPerChannel = 16;
    
    status = AudioUnitSetProperty(self->remoteIOUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  bus0,
                                  &asbd,
                                  sizeof(asbd));
    if (CheckError(status, "Couldn't set the ASBD for RemoteIO on input scope/bus 0")) {
        NSLog(@"error: %s", "Couldn't set the ASBD for RemoteIO on input scope/bus 0");
    }

    // Set format for mic input (bus 1) on RemoteIO's output scope
    status = AudioUnitSetProperty(self->remoteIOUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  bus1,
                                  &asbd,
                                  sizeof(asbd));
    if (CheckError(status, "Couldn't set the ASBD for RemoteIO on output scope/bus 1")) {
        NSLog(@"error: %s", "Couldn't set the ASBD for RemoteIO on output scope/bus 1");
    }
    
    NSLog(@"Start Monitoring4");
    
    // Set the recording callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = recordingCallback;
    callbackStruct.inputProcRefCon = (__bridge void *) self;
    status = AudioUnitSetProperty(self->remoteIOUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  bus1,
                                  &callbackStruct,
                                  sizeof (callbackStruct));
    if (CheckError(status, "Couldn't set RemoteIO's render callback on bus 0")) {
        NSLog(@"error: %s", "Couldn't set RemoteIO's render callback on bus 0");
    }

    if ((NO)) {
      // Set the playback callback
      AURenderCallbackStruct callbackStruct;
      callbackStruct.inputProc = playbackCallback;
      callbackStruct.inputProcRefCon = (__bridge void *) self;
      status = AudioUnitSetProperty(self->remoteIOUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Global,
                                    bus0,
                                    &callbackStruct,
                                    sizeof (callbackStruct));
      if (CheckError(status, "Couldn't set RemoteIO's render callback on bus 0")) {
          NSLog(@"error: %s", "Couldn't set RemoteIO's render callback on bus 0");
      }
    }
    
    NSLog(@"Start Monitoring5");

    // Initialize the RemoteIO unit
    status = AudioUnitInitialize(self->remoteIOUnit);
    if (CheckError(status, "Couldn't initialize the RemoteIO unit")) {
        NSLog(@"error: %s", "Couldn't initialize the RemoteIO unit");
    }
    
    NSLog(@"Start Monitoring6");
    
    status = AudioOutputUnitStart(self->remoteIOUnit);
    if (CheckError(status, "Couldn't start the RemoteIO unit")) {
        NSLog(@"error: %s", "Couldn't start the RemoteIO unit");
    }
    
    NSLog(@"Start Monitoring8");
    
    
    

  //NSURL *_tempFileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"temp"]];

  //_audioRecorder = [[AVAudioRecorder alloc]
  //              initWithURL:_tempFileUrl
  //              settings:recordSettings
  //              error:&error];

  //_audioRecorder.delegate = self;

  //if (error) {
  //    NSLog(@"error: %@", [error localizedDescription]);
  //  } else {
  //    [_audioRecorder prepareToRecord];
  //}

  //_audioRecorder.meteringEnabled = YES;

  //[self startProgressTimer:monitorInterval];
  //[_recordSession setActive:YES error:nil];
  //[_audioRecorder record];
}

RCT_EXPORT_METHOD(stop)
{
  //[_audioRecorder stop];
  [_recordSession setCategory:AVAudioSessionCategoryPlayback error:nil];
  _prevProgressUpdateTime = nil;
    AudioOutputUnitStop(self->remoteIOUnit);
}

@end
