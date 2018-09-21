//
//  ViewController.m
//  assignment-2
//
//  Created by Brandon McFarland on 9/11/18.
//  Copyright © 2018 MobileSensingLearning. All rights reserved.
//

#import "ViewControllerB.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "FFTHelper.h"
#import "SMUGraphHelper.h"

//#define BUFFER_SIZE 2048
#define BUFFER_SIZE 4096
#define minMagnitude 1

@interface ViewControllerB ()
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) Novocaine* audioManager;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;

@property (nonatomic) float frequency;
@property (weak, nonatomic) IBOutlet UILabel *freqLabel;
@property (nonatomic) float phaseIncrement;
@property (weak, nonatomic) IBOutlet UISlider *frequencySlider;
@property (weak, nonatomic) IBOutlet UILabel *labelForDirection;


@end

@implementation ViewControllerB

-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:1
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:BUFFER_SIZE];
    }
    return _graphHelper;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.audioManager pause];
    NSLog(@"Called pause");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    [self.graphHelper setScreenBoundsBottomHalf];
    
    // play the tone
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
    //float phaseInc = 2*M_PI*18000.0/self.audioManager.samplingRate;
    float phaseInc = 2*M_PI*self.frequency/self.audioManager.samplingRate;
    __block float phase = 0.0;
    [self.audioManager setOutputBlock:^(float* data, UInt32 numFrames, UInt32 numChannels){
        for (int n=0; n<numFrames; n++) {
            data[n] = sin(phase);
            phase += self.phaseIncrement;
        }
        
    }];
    
    // read from the mic
    __block ViewControllerB * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    [self.audioManager play];
    
    
    
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

- (void)update{
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    // take forward fft
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    // send off for graphing
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:BUFFER_SIZE/2
                     forGraphIndex:0
                 withNormalization:64.0
                     withZeroValue:-60];
    
    int targetIndex = (self.frequency*((float)BUFFER_SIZE)/((float)self.audioManager.samplingRate));
    //NSLog(@"TARGET INDEX: %i", targetIndex);
    double leftSum = 0;
    double rightSum = 0;
    
    int DEADSPACE = 5;
    int WINDOWSIZE = 20;
    
    for(int i = targetIndex - WINDOWSIZE; i < targetIndex-DEADSPACE; i++){
        //NSLog(@"CURRENT INDEX: %i", i);
        //NSLog(@"INDEX LEFT VALUE: %f", fftMagnitude[i]);
        leftSum += fftMagnitude[i]/fftMagnitude[targetIndex];
    }
    for(int i = targetIndex + WINDOWSIZE; i > targetIndex+DEADSPACE; i--){
        //NSLog(@"CURRENT INDEX: %i", i);
        //NSLog(@"INDEX RIGHT VALUE: %f", fftMagnitude[i]);
        rightSum += fftMagnitude[i]/fftMagnitude[targetIndex];
    }
    //NSLog(@"SUMS: (%.4f, %.4f)", leftSum, rightSum);
    
    float leftAvg = leftSum / WINDOWSIZE;
    float rightAvg = rightSum / WINDOWSIZE;
    float leftRightRatio = leftAvg / rightAvg;

        if(leftRightRatio*0.8 > 1){
            self.labelForDirection.text = @"Away";
        }else if(leftRightRatio*1.2 < 1){
            self.labelForDirection.text = @"Toward";
        }else{
            self.labelForDirection.text = @"No Direction";
        }
    
    // call update
    [self.graphHelper update];
    
    // free memory
    free(arrayData);
    free(fftMagnitude);
    
}

- (IBAction)frequencyChanged:(UISlider *)sender {
    [self updateFrequencyInKhz:sender.value];
}

-(void)updateFrequencyInKhz:(float) freqInKHz {
    self.frequency = freqInKHz*1000.0;
    self.freqLabel.text = [NSString stringWithFormat:@"%.4f kHz",freqInKHz];
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}



@end

//NSLog(@"RATIO: (%.4f)", leftRightRatio);

//NSLog(@"LEFT AVG: %f, %f", leftAvg/leftRightRatio, rightAvg/leftRightRatio);
//        NSLog(@"RIGHT SUM: %f", rightSum);
//        NSLog(@"Left SUM: %f", leftSum);
//NSLog(@"RIGHT AVG: %f", rightAvg);

//    if(leftAvg> rightAvg+.2){
//        self.labelForDirection.text = @"Away";
//    }else if(leftAvg+.2 < rightAvg){
//        self.labelForDirection.text = @"Toward";
//    }else{
//        self.labelForDirection.text = @"No Direction";
//    }

//    if(leftAvg > rightAvg && leftAvg > rightAvg*1.3){
//        self.labelForDirection.text = @"Away";
//    }else if(leftAvg < rightAvg && leftAvg*0.8 < rightAvg){
//        self.labelForDirection.text = @"Toward";
//    }else{
//        self.labelForDirection.text = @"No Direction";
//    }

