//
//  ViewController.m
//  LicensePlate
//
//  Created by shohei.namba on 2018/01/12.
//  Copyright © 2018年 nbapps. All rights reserved.
//

#import "ViewController.h"
#import <opencv2/opencv.hpp>
//#import <opencv2/highgui/ios.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)onClickCameraRole:(id)sender {
    [self photoFromGallary];
}

-(void)photoFromGallary{
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    if(info[UIImagePickerControllerOriginalImage] ){
        UIImage *image =info[UIImagePickerControllerOriginalImage] ;
        [_imageView setImage:image];
        [picker dismissViewControllerAnimated:YES completion:nil];
        
        //ナンバープレート認識
        [self recognizeNumberPlate:image];
    }
}

-(void)recognizeNumberPlate:(UIImage*)image{
    
//    static CvScalar colors[] = {
//        {{0, 0, 255}}, {{0, 128, 255}},
//        {{0, 255, 255}}, {{0, 255, 0}},
//        {{255, 128, 0}}, {{255, 255, 0}},
//        {{255, 0, 0}}, {{255, 0, 255}}
//    };
    // おまじない(結構重要。これが無いと、なかなか認識されない）
    UIGraphicsBeginImageContext(image.size);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // 分類器のカスケードを読み込む
    NSString *path = [[NSBundle mainBundle] pathForResource:@"cascade" ofType:@"xml"];
    CvHaarClassifierCascade* cascade = (CvHaarClassifierCascade*)cvLoad([path cStringUsingEncoding:NSASCIIStringEncoding], 0, 0, 0);
    
    // 画像を IplImage に変換
    IplImage* iplImage = [self IplImageFromUIImage:image];
    
    // グレースケール化
    CvSize smallSize = cvSize(image.size.width, image.size.height);
    
    CvMemStorage *storage = 0;
    IplImage *src_gray = cvCreateImage( smallSize, IPL_DEPTH_8U, 1 );
    
    storage = cvCreateMemStorage (0);
    cvClearMemStorage(storage);
    cvCvtColor(iplImage, src_gray, CV_BGR2GRAY);
    cvEqualizeHist(src_gray, src_gray);
    
    // 顔検出
    CvSeq *faces = cvHaarDetectObjects(src_gray, cascade, storage, 1.11, 3, 0, cvSize (40, 40));
    
    // 検出された顔に矩形描画
    if(faces != NULL && faces->total > 0) {
        
        NSLog(@"顔認識　OK.");
        
        // 検出された全ての顔位置に，円を描画する
        int i;
        for (i = 0; i < (faces ? faces->total : 0); i++) {
            CvRect *r = (CvRect *) cvGetSeqElem (faces, i);
            CvPoint center;
            int radius;
            center.x = cvRound (r->x + r->width * 0.5);
            center.y = cvRound (r->y + r->height * 0.5);
            radius = cvRound ((r->width + r->height) * 0.25);
            cvCircle (iplImage, center, radius, {0, 0, 255}, 3, 8, 0);
        }
        
        // IplImageをUIImageに変換
        self.imageView.image = [self UIImageFromIplImage:iplImage];
        
    } else {
        NSLog(@"顔認識　NG.");
    }
    
    // アルバムに画像を保存
    //UIImageWriteToSavedPhotosAlbum(self.imageView.image, self, nil, nil);
    
}

// UIImage -> IplImage変換
- (IplImage*)IplImageFromUIImage:(UIImage*)image {
    
    CGImageRef imageRef = image.CGImage;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IplImage *iplimage = cvCreateImage(cvSize(image.size.width,image.size.height), IPL_DEPTH_8U, 4 );
    
    CGContextRef contextRef = CGBitmapContextCreate(
                                                    iplimage->imageData,
                                                    iplimage->width,
                                                    iplimage->height,
                                                    iplimage->depth,
                                                    iplimage->widthStep,
                                                    colorSpace,
                                                    kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef,
                       CGRectMake(0, 0, image.size.width, image.size.height),
                       imageRef);
    
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplimage, ret, CV_RGBA2BGR);
    cvReleaseImage(&iplimage);
    
    return ret;
}

// IplImage -> UIImage変換
- (UIImage*)UIImageFromIplImage:(IplImage*)image {
    
    CGColorSpaceRef colorSpace;
    if (image->nChannels == 1)
    {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        //BGRになっているのでRGBに変換
        cvCvtColor(image, image, CV_BGR2RGB);
    }
    NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(image->width,
                                        image->height,
                                        image->depth,
                                        image->depth * image->nChannels,
                                        image->widthStep,
                                        colorSpace,
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault
                                        );
    UIImage *ret = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return ret;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
