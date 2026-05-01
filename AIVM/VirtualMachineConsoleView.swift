import SwiftUI
import Virtualization

struct VirtualMachineConsoleView: NSViewRepresentable {
  let virtualMachine: VZVirtualMachine?

  func makeNSView(context: Context) -> VZVirtualMachineView {
    VZVirtualMachineView()
  }

  func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
    nsView.virtualMachine = virtualMachine
  }
}
