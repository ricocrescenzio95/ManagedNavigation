import SwiftUI

#if canImport(UIKit)
import UIKit

struct OnPresentedNotifier: UIViewControllerRepresentable {
  var onPresented: () -> Void
  
  func makeUIViewController(context: Context) -> PresentedDetectorVC {
    PresentedDetectorVC(onPresented: onPresented)
  }
  
  func updateUIViewController(_ vc: PresentedDetectorVC, context: Context) {
    vc.onPresented = onPresented
  }
  
  class PresentedDetectorVC: UIViewController {
    var onPresented: () -> Void
    
    init(onPresented: @escaping () -> Void) {
      self.onPresented = onPresented
      super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
     
      onPresented()
    }
  }
}
#elseif canImport(AppKit)
import AppKit

struct OnPresentedNotifier: NSViewControllerRepresentable {
  var onPresented: () -> Void
  
  func makeNSViewController(context: Context) -> PresentedDetectorVC {
    PresentedDetectorVC(onPresented: onPresented)
  }
  
  func updateNSViewController(_ vc: PresentedDetectorVC, context: Context) {
    vc.onPresented = onPresented
  }
  
  class PresentedDetectorVC: NSViewController {
    var onPresented: () -> Void
    
    init(onPresented: @escaping () -> Void) {
      self.onPresented = onPresented
      super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidAppear() {
      super.viewDidAppear()
     
      onPresented()
    }
  }
}
#endif
