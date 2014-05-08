// Copyright (c) 2014, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library zengen.transformer;

import 'dart:async' show Future;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:barback/barback.dart';

final MODIFIERS = <ContentModifier>[//
  new ToStringAppender(), //
  new EqualsAndHashCodeAppender(),//
];

abstract class ContentModifier {
  List<Transformation> accept(String content);
}

class ZengenTransformer extends Transformer {
  ZengenTransformer.asPlugin();

  String get allowedExtensions => ".dart";

  Future apply(Transform transform) {
    return transform.primaryInput.readAsString().then((content) {
      final id = transform.primaryInput.id;
      final newContent = traverseModifiers(content);
      if (newContent != content) {
        transform.logger.fine("new content for $id : \n$newContent", asset: id);
        transform.addOutput(new Asset.fromString(id, newContent));
      }
    });
  }
}

String traverseModifiers(String content) {
  bool modifications = true;
  while (modifications) {
    modifications = false;
    for (final modifier in MODIFIERS) {
      final transformations = modifier.accept(content);
      if (transformations.isNotEmpty) {
        content = applyTransformations(content, transformations);
        modifications = true;
        break;
      }
    }
  }
  return content;
}

String applyTransformations(String content, List<Transformation>
    transformations) {
  int padding = 0;
  for (final t in transformations) {
    content = content.substring(0, t.begin + padding) + t.content +
        content.substring(t.end + padding);
    padding += t.content.length - (t.end - t.begin);
  }
  return content;
}

class Transformation {
  final int begin, end;
  final String content;
  Transformation(this.begin, this.end, this.content);
  Transformation.insertion(int index, this.content)
      : begin = index,
        end = index;
}

class ToStringAppender implements ContentModifier {
  @override
  List<Transformation> accept(String content) {
    if (!content.contains('@ToString(')) return [];

    final transformations = [];
    final cu = parseCompilationUnit(content);
    cu.declarations.where(isClassAnnotatedWith('ToString')).forEach(
        (ClassDeclaration clazz) {
      final toString =
          '@generated @override String toString() => "${clazz.name.name}(' +
          getFieldNames(clazz).map((f) => '$f=\$$f').join(', ') + ')";';

      final index = clazz.end - 1;
      if (!isMethodDefined(clazz, 'toString')) {
        transformations.add(new Transformation.insertion(index, '  $toString\n')
            );
      }
    });
    return transformations;
  }
}

class EqualsAndHashCodeAppender implements ContentModifier {
  @override
  List<Transformation> accept(String content) {
    if (!content.contains('@EqualsAndHashCode(')) return [];

    final transformations = [];
    final cu = parseCompilationUnit(content);
    cu.declarations.where(isClassAnnotatedWith('EqualsAndHashCode')).forEach(
        (ClassDeclaration clazz) {
      final fieldNames = getFieldNames(clazz);
      final hashCode = '@generated @override int get hashCode => '
          'hashObjects([' + fieldNames.join(', ') + ']);';
      final equals = '@generated @override bool operator==(o) => '
          'o is ${clazz.name.name}' + fieldNames.map((f) => ' && o.$f == $f').join() +
          ';';

      final index = clazz.end - 1;
      if (!isMethodDefined(clazz, 'hashCode')) {
        transformations.add(new Transformation.insertion(index, '  $hashCode\n')
            );
      }
      if (!isMethodDefined(clazz, '==')) {
        transformations.add(new Transformation.insertion(index, '  $equals\n'));
      }
    });
    return transformations;
  }
}

Iterable<String> getFieldNames(ClassDeclaration clazz) => clazz.members.where(
    (m) => m is FieldDeclaration && !m.isStatic).expand((FieldDeclaration f) =>
    f.fields.variables.map((v) => v.name.name));

isClassAnnotatedWith(String annotation) => (e) => e is ClassDeclaration &&
    e.metadata.any((m) => m.name.name == annotation);

bool isMethodDefined(ClassDeclaration clazz, String methodName) =>
    clazz.members.any((m) => m is MethodDeclaration && m.name.name == methodName);