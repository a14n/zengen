// Copyright (c) 2015, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:source_gen/src/annotation.dart';

LibraryElement getLib(LibraryElement library, String name) => library
    .visibleLibraries.firstWhere((l) => l.name == name, orElse: () => null);

ClassElement getType(
        LibraryElement library, String libName, String className) =>
    getLib(library, libName)?.getType(className);

bool hasAnnotation(Element element, Type type) =>
    element.metadata.any((e) => matchAnnotation(type, e));

getAnnotation(Element element, Type type) => instantiateAnnotation(
    element.metadata.singleWhere((e) => matchAnnotation(type, e)));

Iterable<Annotation> getAnnotations(
    AnnotatedNode node, Type type) sync* {
  if (node == null || node.metadata == null) return;
  for (Annotation a in node.metadata) {
    if (matchAnnotation(type, a.elementAnnotation)) {
      yield a;
    }
  }
}

class SourceTransformation {
  int begin;
  int end;
  final String content;

  SourceTransformation(this.begin, this.end, this.content);
  SourceTransformation.removal(this.begin, this.end) : content = '';
  SourceTransformation.insertion(int index, this.content)
      : begin = index,
        end = index;

  void shift(int value) {
    begin += value;
    end += value;
  }
}

class Transformer {
  final _transformations = <SourceTransformation>[];

  bool get hasTransformations => _transformations.isNotEmpty;

  void insertAt(int index, String content) =>
      _transformations.add(new SourceTransformation.insertion(index, content));

  void removeBetween(int begin, int end) =>
      _transformations.add(new SourceTransformation.removal(begin, end));

  void removeNode(AstNode node) => _transformations
      .add(new SourceTransformation.removal(node.offset, node.end));

  void removeToken(Token token) => _transformations
      .add(new SourceTransformation.removal(token.offset, token.end));

  void replace(int begin, int end, String content) =>
      _transformations.add(new SourceTransformation(begin, end, content));

  String applyOnCode(String code, int initialPadding) {
    _transformations.forEach((e) => e.shift(initialPadding));
    for (var i = 0; i < _transformations.length; i++) {
      final t = _transformations[i];
      code = code.substring(0, t.begin) + t.content + code.substring(t.end);
      _transformations.skip(i + 1).forEach((e) {
        if (e.end <= t.begin) return;
        if (t.end <= e.begin) {
          e.shift(t.content.length - (t.end - t.begin));
          return;
        }
        throw 'Colision in transformations';
      });
    }
    return code;
  }
}
