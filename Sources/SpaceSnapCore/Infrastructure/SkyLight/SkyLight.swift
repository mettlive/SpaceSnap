import CoreFoundation

typealias SkyLightConnectionID = UInt32

@_silgen_name("SLSMainConnectionID")
func SLSMainConnectionID() -> SkyLightConnectionID

@_silgen_name("SLSCopyManagedDisplaySpaces")
func SLSCopyManagedDisplaySpaces(_ connection: SkyLightConnectionID) -> Unmanaged<CFArray>?

@_silgen_name("SLSGetActiveSpace")
func SLSGetActiveSpace(_ connection: SkyLightConnectionID) -> UInt64

@_silgen_name("SLSCopySpacesForWindows")
func SLSCopySpacesForWindows(
    _ connection: SkyLightConnectionID,
    _ mask: Int32,
    _ windows: CFArray
) -> Unmanaged<CFArray>?

@_silgen_name("SLSGetSymbolicHotKeyValue")
func SLSGetSymbolicHotKeyValue(
    _ hotKey: Int32,
    _ keyEquivalent: UnsafeMutablePointer<UInt16>,
    _ virtualKeyCode: UnsafeMutablePointer<UInt16>,
    _ modifiers: UnsafeMutablePointer<UInt32>
) -> Int32

@_silgen_name("SLSIsSymbolicHotKeyEnabled")
func SLSIsSymbolicHotKeyEnabled(_ hotKey: Int32) -> Bool

@_silgen_name("SLSSetSymbolicHotKeyEnabled")
func SLSSetSymbolicHotKeyEnabled(_ hotKey: Int32, _ enabled: Bool) -> Int32
