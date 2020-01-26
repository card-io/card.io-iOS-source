[![card.io logo](Resources/cardio_logo_220.png "card.io")](https://www.card.io)

Credit card scanning for mobile apps
====================================

### Yes, that's right: the [card.io](https://www.card.io) library for iOS is now open-source!

This repository contains everything needed to build the **card.io** library for iOS.

What it does not yet contain is much in the way of documentation. :crying_cat_face: So please feel free to ask any questions by creating github issues -- we'll gradually build our documentation based on the discussions there.

Note that this is actual production code, which has been iterated upon by multiple developers over several years. If you see something that could benefit from being tidied up, rewritten, or otherwise improved, your Pull Requests will be welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

Brought to you by  
[![PayPal logo](Resources/pp_h_rgb.png)](https://paypal.com/ "PayPal")


Using **card.io**
-----------------

If you merely wish to incorporate **card.io** within your iOS app, simply download the latest official release from https://github.com/card-io/card.io-iOS-SDK. That repository includes complete integration instructions and sample code.

### If you use [CocoaPods](https://cocoapods.org), then add this line to your podfile:

```ruby
pod 'CardIO'
```

### If you use [Carthage](https://github.com/Carthage/Carthage), then add this line to your Cartfile:

```
github "card-io/card.io-iOS-source"
```

You must also have an SSH key setup with GitHub so that the dmz submodule will download properly. See the [documentation here](https://help.github.com/articles/testing-your-ssh-connection/) for directions.

Dev setup
---------

* clone this repo, including its `dmz` submodule: `git submodule sync; git submodule update --init --recursive`
* requires Xcode 5+ (toolchain for iOS 7)
* requires Python 2.6+
* for building releases, requires [`pip`](http://www.pip-installer.org/) and [`fabric`](http://www.fabfile.org)

### Python

We use Python-based build scripts.

 If you are using [virtualenv](https://virtualenv.pypa.io) and [virtualenvwrapper](http://www.doughellmann.com/docs/virtualenvwrapper), create a virtual environment (optional but recommended):

    # Create virtual environment for Python
    mkvirtualenv cardio

Install required Python dependencies (this command may require sudo rights if installing globally):

    # Install required dependencies
    pip install -r pip_requirements.txt


### Baler

We use [baler](https://github.com/paypal/baler) (included in `pip_requirements.txt`) to encode assets (strings and images) within our library. Create a `.baler_env` file in the top project directory, and set the `$PATH` environment variable to include where you installed baler. Examples:

```
    # Create a .baler_env, specifying the correct path for an installation using virtualenv
    echo 'export PATH=$PATH:~/.virtualenvs/cardio/bin' > .baler_env
    
    # - OR -

    # Create a .baler_env, specifying the correct path if not using virtualenv
    echo 'export PATH=$PATH:'`dirname \`which bale\`` > .baler_env
```

### card.io-dmz

The [card.io-dmz](https://github.com/card-io/card.io-dmz) submodule (included here in the `dmz` directory) includes the core image-processing code.


Normal development
------------------

Use Xcode in a normal fashion to build the library. The project's `icc` target is a demo app which will allow you to exercise the library in various ways.


Unofficial card.io-iOS-SDK release
----------------------------------

How to make a Release build of the library for your own use:

* Run `fab build:outdir=~` (or specify some other output directory).


Official card.io-iOS-SDK release
--------------------------------

[How official releasers officially make an official release of card.io-iOS-SDK](official_release.md)


Contributors
------------

**card.io** was created by [Josh Bleecher Snyder](https://github.com/josharian/).

Subsequent help has come from [Brent Fitzgerald](https://github.com/burnto/), [Tom Whipple](https://github.com/tomwhipple), [Dave Goldman](https://github.com/dgoldman-ebay), [Roman Punskyy](https://github.com/romk1n), [Mark Rogers](https://github.com/mgroger2), and [Martin Rybak](https://github.com/martinrybak).

And from **you**! Pull requests and new issues are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.
