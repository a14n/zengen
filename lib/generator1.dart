// Copyright (c) 2015, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

library zengen.generator;

import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_gen/src/utils.dart';
import 'package:zengen/src/util.dart';
import 'package:zengen/zengen.dart';

final _zengenLibName = 'zengen';

class ZengenGenerator extends Generator {
  final List<ContentModifier> modifiers = <ContentModifier>[
    // new ImplementationModifier(),
    new ValueContentModifier(),
    new DefaultConstructorContentModifier(),
    new ToStringContentModifier(),
    new EqualsAndHashCodeContentModifier(),
    // new DelegateAppender(),
    // new LazyModifier(),
    // new CachedModifier(),
  ];

  ZengenGenerator();

  Future<String> generate(Element element) async {
    if (element is LibraryElement) {
      // create a temporary file to avoid races if changes are applied on the
      // current lib.
      final tmpLib = createTmpLib(element);

      // remove generated part section to avoid dupplicated names
      final generatedPartName = element.source.shortName
              .substring(0, element.source.shortName.length - 5) +
          '.g.dart';
      final partDirective = tmpLib.unit.directives.firstWhere(
          (d) => d is PartDirective && d.uriContent == generatedPartName,
          orElse: () => null);
      if (partDirective != null) {
        int offset = partDirective.offset;
        int end = partDirective.end;
        tmpLib.context.applyChanges(new ChangeSet()
          ..changedContent(
              tmpLib.source,
              tmpLib.context
                  .getContents(tmpLib.source)
                  .data
                  .replaceRange(offset, end, '')));
      }

      final initialContent = tmpLib.context.getContents(tmpLib.source).data;

      // elements that are changed
      final elementsChanged = <String>[];

      // copy all template element and unprivate them
      String incrementalContent = '';
      final handledElements = getElementsFromLibraryElement(tmpLib).where(
          (element) => modifiers.any((modifier) => modifier.accept(element)));
      for (final element in handledElements) {
        if (element.isPublic) throw 'The template $element must be private';
        if (element is ClassElement) {
          // remove leading '_' of Class name
          final newClassName = element.displayName.substring(1);
          final ClassDeclaration classNode = element.computeNode();
          final transformer = new Transformer();
          transformer.insertAt(
              classNode.offset, '@GeneratedFrom(${element.displayName})');
          transformer.replace(
              classNode.name.offset, classNode.name.end, newClassName);

          for (final constr
              in classNode.members.where((e) => e is ConstructorDeclaration)) {
            transformer.replace(
                constr.returnType.offset, constr.returnType.end, newClassName);
          }
          incrementalContent += transformer.applyOnCode(
              initialContent.substring(classNode.offset, classNode.end),
              -classNode.offset);

          elementsChanged.add(newClassName);
        }
      }
      tmpLib.context.applyChanges(new ChangeSet()
        ..changedContent(tmpLib.source, initialContent + incrementalContent));

      // incremental modifications
      loop: while (elementsChanged.isNotEmpty) {
        if (new String.fromEnvironment("debug") != null) {
          print(incrementalContent);
        }
        final handledElements = getElementsFromLibraryElement(tmpLib)
            .where((element) => elementsChanged.contains(element.name));
        for (final element in handledElements) {
          for (final modifier in modifiers) {
            if (!modifier.accept(element)) continue;
            final transformer = new Transformer();
            modifier.visit(element, transformer);
            if (transformer.hasTransformations) {
              incrementalContent = transformer.applyOnCode(
                  incrementalContent, -initialContent.length);
              tmpLib.context.applyChanges(new ChangeSet()
                ..changedContent(
                    tmpLib.source, initialContent + incrementalContent));
              continue loop;
            }
          }
          elementsChanged.remove(element.name);
        }
      }
      tmpLib.context
          .applyChanges(new ChangeSet()..removedSource(tmpLib.source));

      return incrementalContent;
    }
    return null;
  }

  /// Create a duplicated library of [library].
  LibraryElement createTmpLib(LibraryElement library) {
    final context = library.context;
    final librarySource = context.librarySources
        .firstWhere((s) => context.getLibraryElement(s) == library);
    final initialContent = context.getContents(librarySource).data;

    final tmpLibSource = new FileBasedSource(new JavaFile(librarySource.fullName
            .substring(0, librarySource.shortName.length - 5) +
        '.tmp-${new DateTime.now().millisecondsSinceEpoch}.dart'));
    context.applyChanges(new ChangeSet()
      ..addedSource(tmpLibSource)
      ..changedContent(tmpLibSource, initialContent));
    return context.computeLibraryElement(tmpLibSource);
  }
}

abstract class ContentModifier {
  bool accept(Element element);
  void visit(Element element, Transformer transformer);
}

class ToStringContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && hasAnnotation(element, ToString);

  @override
  void visit(ClassElement clazz, Transformer transformer) {
    final classNode = clazz.computeNode();
    final ToString annotation = getAnnotation(clazz, ToString);

    getAnnotations(classNode, ToString)
        .forEach((e) => transformer.removeNode(e));

    final callSuper = annotation.callSuper == true;
    final exclude = <Symbol>[#hashCode];
    if (annotation.exclude != null) exclude.addAll(annotation.exclude);
    final includePrivate = annotation.includePrivate == true;

    final getters = clazz.accessors
        .where((e) =>
            e.isGetter && !e.isStatic && (includePrivate || !e.isPrivate))
        .map((e) => e.name)
        .where((e) => !exclude.contains(new Symbol(e)));

    final content = '@override String toString() => "${clazz.displayName}(' +
        (callSuper ? r'super=${super.toString()}' : '') +
        (callSuper && getters.isNotEmpty ? ', ' : '') +
        getters.map((f) => '$f=\$$f').join(', ') +
        ')";';

    if (!clazz.methods.any((m) => m.name == 'toString')) {
      transformer.insertAt(classNode.end - 1, content);
    }
  }
}

class EqualsAndHashCodeContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && hasAnnotation(element, EqualsAndHashCode);

  @override
  void visit(ClassElement clazz, Transformer transformer) {
    final classNode = clazz.computeNode();
    final EqualsAndHashCode annotation =
        getAnnotation(clazz, EqualsAndHashCode);

    getAnnotations(classNode, EqualsAndHashCode)
        .forEach((e) => transformer.removeNode(e));

    final callSuper = annotation.callSuper == true;
    final exclude = <Symbol>[#hashCode];
    if (annotation.exclude != null) exclude.addAll(annotation.exclude);
    final includePrivate = annotation.includePrivate == true;

    final getters = clazz.accessors
        .where((e) =>
            e.isGetter && !e.isStatic && (includePrivate || !e.isPrivate))
        .map((e) => e.name)
        .where((e) => !exclude.contains(new Symbol(e)));

    final hashCodeValues = getters.toList();
    if (callSuper) hashCodeValues.insert(0, 'super.hashCode');
    final hashCode = '@override int get hashCode => '
        'hashObjects([' +
        hashCodeValues.join(', ') +
        ']);';

    final equals = '@override bool operator ==(o) => identical(this, o) || '
        'o.runtimeType == runtimeType' +
        (callSuper ? ' && super == o' : '') +
        getters.map((f) => ' && o.$f == $f').join() +
        ';';

    if (!clazz.methods.any((m) => m.name == 'hashCode')) {
      transformer.insertAt(classNode.end - 1, hashCode);
    }
    if (!clazz.methods.any((m) => m.name == '==')) {
      transformer.insertAt(classNode.end - 1, equals);
    }
  }
}

class DefaultConstructorContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && element.constructors.any(acceptConstructor);

  static bool acceptConstructor(ConstructorElement constructor) =>
      constructor.isExternal && hasAnnotation(constructor, DefaultConstructor);

  @override
  void visit(ClassElement clazz, Transformer transformer) {
    clazz.constructors.where(acceptConstructor).forEach(
        (constructor) => replaceConstructor(clazz, transformer, constructor));
  }

  void replaceConstructor(ClassElement clazz, Transformer transformer,
      ConstructorElement constructor) {
    final DefaultConstructor annotation =
        getAnnotation(constructor, DefaultConstructor);

    final fields = clazz.fields.where((e) => !e.isStatic);

    final requiredVariables =
        fields.where((e) => e.isFinal).where((e) => e.initializer == null);
    final mutableVariables = fields.where((e) => !e.isFinal);

    var code = '';
    if (annotation.useConst == true) code += 'const ';
    code += clazz.displayName;
    if (constructor.name.isNotEmpty) code += '.' + constructor.name;
    code += '(';
    code += requiredVariables.map((e) => 'this.${e.name}').join(', ');
    if (mutableVariables.isNotEmpty) {
      if (requiredVariables.isNotEmpty) code += ', ';
      code += '{';
      code += mutableVariables.map((e) => 'this.${e.name}').join(', ');
      code += '}';
    }
    code += ');';

    final constructorNode = constructor.computeNode();
    transformer.replace(constructorNode.offset, constructorNode.end, code);
  }
}

class ValueContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && hasAnnotation(element, Value);

  @override
  void visit(ClassElement clazz, Transformer transformer) {
    final classNode = clazz.computeNode();
    final Value annotation = getAnnotation(clazz, Value);

    getAnnotations(classNode, Value).forEach((e) => transformer.removeNode(e));

    if (!hasAnnotation(clazz, ToString)) {
      transformer.insertAt(classNode.offset, '@ToString()');
    }
    if (!hasAnnotation(clazz, EqualsAndHashCode)) {
      transformer.insertAt(classNode.offset, '@EqualsAndHashCode()');
    }
    clazz.constructors
        .where((constructor) => constructor.isExternal &&
            !hasAnnotation(constructor, DefaultConstructor))
        .forEach((constructor) {
      print(constructor);
      print(constructor.computeNode());
      transformer.insertAt(constructor.computeNode().offset,
          '@DefaultConstructor(useConst:${annotation.useConst})');
    });
  }
}
