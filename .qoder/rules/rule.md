trigger: always_on
alwaysApply: true
---
For any defect, first read the code to deduce the cause (at least two possible causes), outline solutions, then seek human confirmation before proceeding.

For any requirement raised by a human, if there are uncertainties, you must inquire and confirm with the human; once execution begins, ensure full implementation without leaving any TODOs.

All text must be internationalization-friendly; no hard-coded strings should appear in the UI.

When encountering failures, seek human confirmation; do not independently resort to workarounds.

For downloading dependencies, images, files, etc., always use domestic mirrors for acceleration whenever possible.

For terminal commands requiring sudo privileges, alert the human to take over the operation instead of seeking alternatives.

Maintain only a single automated test script.

Maintain only a single automated deployment script.

Maintain only a single automated build script.

Do not use hard-coded text; all displayed text must support internationalization.

If you create a new page, component, or use a new API, remember to update the corresponding documentation.
