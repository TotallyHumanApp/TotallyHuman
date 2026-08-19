Totally Human — AI Music Detector

Native macOS app for detecting AI-generated music.

Open in Xcode

Double-click TotallyHuman.xcodeproj

Signing: Select your Team or use “Sign to Run Locally”

Press Cmd+R to run the app

Language (German / English)

The app is bilingual. You can switch the language at any time under
Settings → Language between German and English.

The interface switches immediately (live) and your selection is saved for the next launch.

System Requirements
macOS 13.0 (Ventura) or later
Xcode 15+


Algorithm
The app detects AI-generated music using:
Fourier artifact analysis (regular peaks between 5–16 kHz)
Self-similarity matrix (MFCC-based)
Splice detection (temporal inconsistencies)
Obfuscation detection

The result is displayed as a percentage, showing how much of the analyzed music is estimated to be AI-generated versus human-made.

Training
Under Training, you can add your own examples.
The training database is stored at:

~/Library/Application Support/TotallyHuman/

It is expanded incrementally with each training session.

Support & Links

If you like the project and want to support its development:

Support the project: https://ko-fi.com/totallyhumanapp/
GitHub: https://github.com/TotallyHumanApp/
Instagram: https://www.instagram.com/totallyhumanapp/
Contact: totallyhumanapp@gmail.com