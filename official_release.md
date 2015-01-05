Official card.io-iOS-SDK release
--------------------------------

How to make an official card.io-iOS-SDK release:

* To make any changes to `acknowledgments.md`, `LICENSE.md`, `README.md`, `CardIO.podspec`, or `release_notes.txt`, you'll find the original files in your card.io-iOS-SDK project's `Release` folder.
* Update `release_notes.txt` with any public-facing changes.
* Update `CardIO.podspec` to reflect the new version number. (Also double-check iOS version for `spec.platform` and `spec.ios.deployment-target`.)
* Run `fab build:outdir=~` (or specify some other output directory).
* In the resulting directory, take a pass through all public-facing files (header files, release notes, etc.) to make sure they're up to date, clear, and perfect. Except for the **card.io** version number, which we'll fix in just a bit.
* If needed, get someone else to read all public-facing files. Making them pretty and flawless is very important. :)
* Test the generated library in a new project (e.g. the Sample App), as a sanity check.
* Run `pod lib lint` to confirm that CardIO.podspec isn't broken. If it is, fix as necessary.
* Tag the card.io-iOS-SDK commit used for the release. The convention for the tag is of the form "iOS_x.y.z".
    [Note to GUI-using people: make an *annotated* tag, via command line `git tag -a iOS_x.y.z -m 'iOS_x.y.z'`.]
* Run the `fab build:outdir=~` command again, and confirm that now the correct version number appears in the header files.
* Merge and push to card.io-iOS-source `master`
* Now we'll update the card.io-iOS-SDK repo:
  1. From the folder created by the second `fab build` you did, just a couple of steps ago, copy all files and folders to your local clone of the github.com `card.io-iOS-SDK` repo.
  2. Commit to your local clone of the github `card.io-iOS-SDK` repo with a commit message of the form "Release x.y.z".
  3. Tag the card.io-iOS-SDK commit used for the release. The convention for the tag is of the form "x.y.z".
    [Note to GUI-using people: make an *annotated* tag, via command line `git tag -a x.y.z -m x.y.z`.]
  4. Push to github.com card.io-iOS-SDK.
* Next, we'll create the "Release" on github.com:
  1. Go to `https://github.com/card-io/card.io-iOS-SDK/releases`.
  2. Click the `Draft a new release` button.
  3. For `Tag version` enter `x.y.z`, where `x.y.z` is the new SDK version number. (GitHub should then indicate that this is an existing tag.)
  4. Fill in `Release title` and `Describe this release` as you please. (See previous Releases for examples.)
  5. Click `Publish release`.
  6. Back on the "Releases" page, admire your results.
* Next, we'll update CocoaPods.
  1. In Terminal, `cd` to your local card.io-iOS-SDK directory.
  2. Run `pod trunk push CardIO.podspec`.
* Post appropriate notifications on (1) Twitter and (2) https://groups.google.com/forum/#!forum/card-io-sdk-announce
* Update the library in [our Cordova/Phonegap Plugin repo](https://github.com/card-io/card.io-iOS-SDK-PhoneGap) under `src/ios/CardIO`.
* And don't forget to update PayPal-iOS-SDK!
