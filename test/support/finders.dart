import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The button of type [T] that shows [text]. Unlike
/// `find.widgetWithText(T, text)`, it also finds subtypes of [T]: before
/// Flutter 3.41, `FilledButton.icon` and the other `.icon` constructors
/// build private subclasses, which an exact type match misses.
Finder buttonWithText<T extends Widget>(String text) =>
    find.ancestor(of: find.text(text), matching: find.bySubtype<T>());
