import SwiftUI

struct OnPresentedNotifier {
  var onPresented: () -> Void
  var onDismissed: () -> Void
}

#if canImport(UIKit)
import UIKit

extension OnPresentedNotifier: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> PresentedDetectorVC {
    PresentedDetectorVC(onPresented: onPresented, onDismissed: onDismissed)
  }
  
  func updateUIViewController(_ vc: PresentedDetectorVC, context: Context) {
    vc.onPresented = onPresented
    vc.onDismissed = onDismissed
  }
  
  class PresentedDetectorVC: UIViewController {
    var onPresented: () -> Void
    var onDismissed: () -> Void
    
    var isPresented = false

    init(onPresented: @escaping () -> Void, onDismissed: @escaping () -> Void) {
      self.onPresented = onPresented
      self.onDismissed = onDismissed
      super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
     
      if !isPresented {
        onPresented()
        isPresented = true
      }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      
      onDismissed()
      isPresented = false
    }
  }
}
#elseif canImport(AppKit)
import AppKit

extension OnPresentedNotifier: NSViewControllerRepresentable {
  func makeNSViewController(context: Context) -> PresentedDetectorVC {
    PresentedDetectorVC(onPresented: onPresented, onDismissed: onDismissed)
  }
  
  func updateNSViewController(_ vc: PresentedDetectorVC, context: Context) {
    vc.onPresented = onPresented
    vc.onDismissed = onDismissed
  }
  
  class PresentedDetectorVC: NSViewController {
    var onPresented: () -> Void
    var onDismissed: () -> Void
    
    init(onPresented: @escaping () -> Void, onDismissed: @escaping () -> Void) {
      self.onPresented = onPresented
      self.onDismissed = onDismissed
      super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidAppear() {
      super.viewDidAppear()
     
      onPresented()
    }
    
    override func viewDidDisappear() {
      super.viewDidDisappear()
      
      onDismissed()
    }
  }
}
#endif
