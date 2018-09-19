//
//  ViewController.m
//  assignment-2
//
//  Created by Brandon McFarland on 9/11/18.
//  Copyright © 2018 MobileSensingLearning. All rights reserved.
//

#import "ViewControllerA.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "FFTHelper.h"
#import "SMUGraphHelper.h"

#define BUFFER_SIZE 2048

@interface ViewControllerA ()
@property (nonatomic) float frequency;
@property (weak, nonatomic) IBOutlet UILabel *freqLabel;
@property (weak, nonatomic) IBOutlet UILabel *dbLabel;
@property (strong, nonatomic) Novocaine* audioManager;
@property (nonatomic) float phaseIncrement;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;

@end

@implementation ViewControllerA

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
                                                       numGraphs:0
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:BUFFER_SIZE];
    }
    return _graphHelper;
}

-(void ) viewDidDisappear {
    [self.audioManager pause];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
    float phaseInc = 2*M_PI*440.0/self.audioManager.samplingRate;
    __block float phase = 0.0;
    [self.audioManager setOutputBlock:^(float* data, UInt32 numFrames, UInt32 numChannels){
        
        for (int n=0; n<numFrames; n++) {
            data[n] = sin(phase);
            phase += self.phaseIncrement;
        }
        
    }];
    
    [self.audioManager play];
    
    __block ViewControllerA * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
}

- (void)update{
    NSLog(@"CALLED UPDATEf");
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    self.dbLabel.text = [NSString stringWithFormat:@"%i dB",fftMagnitude];
    [self.graphHelper update];
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



@end
