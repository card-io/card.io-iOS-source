# Contribute to the card.io iOS SDK

### *Pull requests are welcome!*


General Guidelines
------------------

* **Code style.** Please follow local code style. Ask if you're unsure. Python code should conform to PEP8.
* **No warnings.** All generated code must compile without warnings. All generated code must pass the static analyzer. All python code must run without warnings.
* **iOS version support.** The library should support one major iOS version back. E.g., if iOS 8.x is the newest version of iOS, then the code should build and run correctly in an app targeting and deployed on iOS 7.x.
* **Architecture support.** The library should support armv7, armv7s, arm64, i386 and x86_64.
* **ARC agnostic.** No code that depends on the presence or absence of ARC should appear in public header files.
* **No logging in Release builds.** Always use the `CardIOLog()` macro rather than `NSLog()`.
* **Testing.** Test both with the `icc` demo app, and with the included `ScanExample` sample app. Test both on the iOS simulator and on at least one physical device.
