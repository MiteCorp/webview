import 'dart:io';

import 'package:image/image.dart' as image;

const String _foregroundPath = 'assets/branding/app_icon_foreground.png';
const String _outputPath = 'assets/branding/app_icon.png';

void main() {
  final image.Image? foreground = image.decodePng(
    File(_foregroundPath).readAsBytesSync(),
  );
  if (foreground == null) {
    throw StateError('Ikon sumber tidak dapat dibaca: $_foregroundPath');
  }

  final image.Image canvas = image.Image(
    width: 1024,
    height: 1024,
    numChannels: 3,
  );
  image.fill(canvas, color: image.ColorRgb8(0x12, 0x12, 0x12));
  image.compositeImage(canvas, foreground);

  File(_outputPath).writeAsBytesSync(image.encodePng(canvas));
  stdout.writeln('Ikon launcher RGB dibuat di $_outputPath');
}
