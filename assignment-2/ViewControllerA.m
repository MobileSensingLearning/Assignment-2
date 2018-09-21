//
//  ViewController.m
//  AudioLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

#import "ViewControllerA.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"

#define BUFFER_SIZE  2048*4// 4096

@interface ViewControllerA ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (weak, nonatomic) IBOutlet UILabel *maxLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondMaxLabel;
@end



@implementation ViewControllerA

#pragma mark Lazy Instantiation
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

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:2
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:BUFFER_SIZE];
    }
    return _graphHelper;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}


#pragma mark VC Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.maxLabel.text = [NSString stringWithFormat:@"%d HZ", -1000];
    self.secondMaxLabel.text = [NSString stringWithFormat:@"%d Hz", -1000];

    [self.graphHelper setFullScreenBounds];
    
    __block ViewControllerA * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    [self.audioManager play];
}

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    const int SIZE = BUFFER_SIZE/2;
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];  // putting the data into arrayData
    
    //send off for graphing
    [self.graphHelper setGraphData:arrayData
                    withDataLength:BUFFER_SIZE
                     forGraphIndex:0];
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    const int WINDOW_SIZE = 35; // window size fixed now
    NSMutableArray *maxMagnitude = [ [NSMutableArray alloc] init];
    NSMutableArray *peakMagnitude = [ [NSMutableArray alloc] init];
    NSMutableArray *peakFrequency = [ [NSMutableArray alloc] init];
    
    for(unsigned int i = 0; i < SIZE-WINDOW_SIZE; i+=1)
    {
        float max = -1000.0;
        int max_idx = 0;
        for(unsigned int j = i; j < i + WINDOW_SIZE; j++) {
            if(fftMagnitude[j] > max) {
                max = fftMagnitude[j]; // index in arrayData that has the highest frequency
                max_idx = j;
            }
         }
        
        
        if(max_idx == ( i + (WINDOW_SIZE/2))) { // if in center
            [peakMagnitude addObject:[NSNumber numberWithInt:fftMagnitude[max_idx]]];
            [peakFrequency addObject:[NSNumber numberWithInt:max_idx]]; // index in array is the frequency
        }
        
        
           
           // go back thru peakMag and see which 2 were largest
        float max1magnitude = -1000, max2magnitude = -1000;
        for (NSInteger i = 0; i < [peakMagnitude count]; ++i) {
            float magnitude = [peakMagnitude[i] floatValue];
            if (magnitude > max1magnitude) {
                max2magnitude = max1magnitude;
                max1magnitude = magnitude;
            } else if (magnitude > max2magnitude && magnitude < max1magnitude) {
                max2magnitude = magnitude;
            }
        }
        
        float max1frequency = -1000, max2frequency = -1000;
           // grab 2 index
        for (NSInteger i = 0; i < [peakMagnitude count]; ++i) {
            if([peakMagnitude[i] floatValue] == max1magnitude) {
                max1frequency = [peakFrequency[i] floatValue];
            }
            
            if([peakMagnitude[i] floatValue] == max2magnitude) {
                max2frequency = [peakFrequency[i] floatValue];
            }
        }
        
//        NSLog(@"Max1frequency: %f", max1frequency);
//        NSLog(@"Max2frequency: %f", max2frequency);

        float maxLabel_value = [self.maxLabel.text floatValue];
        float maxLabel2_value = [self.secondMaxLabel.text floatValue];
       
        
        if(max1frequency > maxLabel_value) {
            self.maxLabel.text =  [NSString stringWithFormat:@"%f", max1frequency];
            self.secondMaxLabel.text =  [NSString stringWithFormat:@"%f", maxLabel_value];

        }  else if(max1frequency > maxLabel2_value && max1frequency < maxLabel2_value) {
            self.secondMaxLabel.text =  [NSString stringWithFormat:@"%f", max1frequency];
        }
        
        if(max2frequency > maxLabel2_value && max2frequency < maxLabel_value) {
            self.secondMaxLabel.text =  [NSString stringWithFormat:@"%f", max2frequency];
        }

        
        [maxMagnitude addObject: [NSNumber numberWithInt:max]];
    }
    
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:BUFFER_SIZE/2
                     forGraphIndex:1
                 withNormalization:64.0
                     withZeroValue:-60];
    
    [self.graphHelper update]; // update the graph
    free(arrayData);
    free(fftMagnitude);
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}


@end
