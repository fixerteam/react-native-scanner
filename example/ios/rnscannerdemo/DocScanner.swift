import Foundation
import WeScan
import Photos

@objc(DocScanner)
class DocScanner: NSObject {
    var resolve:RCTPromiseResolveBlock!
    var reject:RCTPromiseRejectBlock!
    
    private func authorizeToAlbum(completion:@escaping (Bool)->Void) {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    DispatchQueue.main.async(execute: {
                        completion(true)
                    })
                } else {
                    DispatchQueue.main.async(execute: {
                        completion(false)
                    })
                }
            })
        } else {
            DispatchQueue.main.async(execute: {
                completion(true)
            })
        }
    }
    
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }

    func takePhotoFromCamera() {
        let scannerVC = ImageScannerController()
        scannerVC.imageScannerDelegate = self
        RCTPresentedViewController()?.present(scannerVC, animated: true, completion: nil)
    }
    
    func takePhotoFromGallery() {
        self.authorizeToAlbum { (authorized) in
            if authorized == true {
                let imagePickerController = UIImagePickerController()
                imagePickerController.sourceType = .photoLibrary
                imagePickerController.delegate = self
                
                RCTPresentedViewController()?.present(imagePickerController, animated: true)
            }
        }
    }
    
    
    @objc
    func startScan(_ options: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
        
        self.resolve = resolve
        self.reject = reject
        
        if (options == "camera") {
            takePhotoFromCamera()
            return
        }
        else if (options == "gallery") {
            takePhotoFromGallery()
            return
        }
        
        DispatchQueue.main.async {
            
            // контроллер показа выбора источника изображения
            let alertController = UIAlertController(title: "Select source...", message: nil, preferredStyle: .alert)
            
            // действие получения скана с фотографии - первоначально заложенное поведение библиотеки
            let takePhotoAction = UIAlertAction(title: "Take Photo...", style: .default) { [weak self] (action:UIAlertAction) in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.takePhotoFromCamera()
            }
            
            //  действие показа галереи для выбора изображения в котором будет происходить детектирование четырехугольника
            let chooseFromLibraryAction = UIAlertAction(title: "Choose from Library...", style: .default) { [weak self] (action:UIAlertAction) in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.takePhotoFromGallery()
                
            }
            
            // действие отмены диалога выбора источника для детектирования четырехугольника
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction) in
                print("You've pressed cancel");
            }
            
            alertController.addAction(takePhotoAction)
            alertController.addAction(chooseFromLibraryAction)
            alertController.addAction(cancelAction)
            
            RCTPresentedViewController()?.present(alertController, animated: true)
        }
    }
}

extension DocScanner: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // получая результат определения прямоугольника решает с какими параметрами вызвать главный контроллер библиотеки
    private func handleRectangleDetection(_ image: UIImage, rectangle: Quadrilateral?) {
        var quad:Quadrilateral?
        if let rectangle = rectangle {
            quad = rectangle.toCartesian(withHeight: image.size.height)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let scannerVC = ImageScannerController(withImage: image, quad: quad)
            scannerVC.imageScannerDelegate = strongSelf
            
            RCTPresentedViewController()?.present(scannerVC, animated: true, completion: nil)
        }
    }
    
    private func detectRectangle(_ image:UIImage) {
        if #available(iOS 11.0, *) {
            VisionRectangleDetector.rectangle(forImage: CIImage(image:image)! ) { (rectangle) in
                self.handleRectangleDetection(image, rectangle:rectangle)
            }
        } else {
            CIRectangleDetector.rectangle(forImage: CIImage(image:image)!) { (rectangle) in
                self.handleRectangleDetection(image, rectangle:rectangle)
            }
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate Methods
    
    // картинка выбрана из галлереи
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[.originalImage] as? UIImage {
            // скрываем галлерею
            RCTPresentedViewController()?.dismiss(animated: false)
            
            detectRectangle(pickedImage)
        }
        else {
            RCTPresentedViewController()?.dismiss(animated: true)
        }
    }
    
    // отказа от выбора картинки из галлереи
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        RCTPresentedViewController()?.dismiss(animated: true)
    }
}

// MARK: - ImageScannerControllerDelegate Methods
extension DocScanner: ImageScannerControllerDelegate {
    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
        self.reject(String(error._code), error.localizedDescription, error)
    }
    
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
        
        DispatchQueue.main.async {
            scanner.dismiss(animated: true, completion: nil)
        }
        
        DispatchQueue.global(qos: .utility ).async {
            //      let width = results.scannedImage.size.width
            //      let height = results.scannedImage.size.height
            
            
            let imageData: Data! = results.scannedImage.jpegData(compressionQuality: 1)
            
            var error: NSError?
            let path:String! = RCTTempFilePath("jpg", &error)
            
            
            if (error != nil || path == nil) {
                DispatchQueue.main.async { [weak self] in
                    self?.reject("error", "unable to make temporal file", error)
                }
            }
            else {
                do {
                    try imageData.write(to: URL(fileURLWithPath: path!), options: .atomic)
                    DispatchQueue.main.async { [weak self] in
                        self?.resolve(path!)
                    }
                } catch let _ {
                    DispatchQueue.main.async { [weak self] in
                        self?.reject("error", "unable to write file " + path!, nil)
                    }
                }
            }
        }
    }
    
    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        DispatchQueue.main.async {
            scanner.dismiss(animated: true, completion: nil)
        }
        
        self.reject("E_PICKER_CANCELLED", "Cancel", nil)
    }
}

