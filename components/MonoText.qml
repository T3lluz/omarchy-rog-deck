import QtQuick

// Text in Monocraft, drawn without antialiasing. Monocraft is pixel art, and
// at the panel's sizes a font pixel is rarely a whole number of device
// pixels (12 px at a 1.25 scale is 1.67 of them), so smoothed edges came out
// soft. Unsmoothed, every stroke lands on whole device pixels and stays
// sharp; the text is the same width either way. Every text ROG Deck draws
// itself is one of these (Decode too); the panel kit's are its own.
Text {
  antialiasing: false
}
