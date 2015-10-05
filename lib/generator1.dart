// Copyright (c) 2015, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

library zengen.generator;

import 'dart:async';
import 'dart:mirrors';

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
    new DelegateContentModifier(),
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
      transformer.insertAt(constructor.computeNode().offset,
          '@DefaultConstructor(useConst:${annotation.useConst})');
    });
  }
}

class DelegateContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && element.accessors.any(acceptAccessor);

  static bool acceptAccessor(PropertyAccessorElement accessor) =>
      accessor.isGetter &&
          !accessor.isStatic &&
          hasAnnotation(
              accessor.isSynthetic ? accessor.variable : accessor, Delegate);

  @override
  void visit(ClassElement clazz, Transformer transformer) {
    clazz.accessors
        .where(acceptAccessor)
        .forEach((accessor) => generateMembers(clazz, transformer, accessor));
  }

  void generateMembers(ClassElement clazz, Transformer transformer,
      PropertyAccessorElement accessor) {
    final ClassDeclaration classNode = clazz.computeNode();
    final Delegate annotation = getAnnotation(
        accessor.isSynthetic ? accessor.variable : accessor, Delegate);
    final type = accessor.returnType;

    //add implements
    if (annotation.addImplements) {
      if (classNode.implementsClause == null) {
        transformer.insertAt(classNode.leftBracket.offset, ' implements $type');
      } else {
        transformer.insertAt(classNode.implementsClause.end, ', $type');
      }
    }

    // remove @Delegate
    final annotations = getAnnotations(
        accessor.isSynthetic
            ? ((accessor.variable.computeNode() as VariableDeclaration).parent
                as VariableDeclarationList).parent
            : accessor.computeNode(),
        Delegate);
    for (final annotation in annotations) {
      transformer.removeNode(annotation);
    }

    final genericsMapping = <DartType, DartType>{};
    if (type is ParameterizedType) {
      for (var i = 0; i < type.typeParameters.length; i++) {
        genericsMapping[type.element.typeParameters[i].type] =
            type.typeArguments[i];
      }
    }
    final excludes = <String>[
      'hashCode',
      'runtimeType',
      '==',
      'toString',
      'noSuchMethod'
    ]
      ..addAll(clazz.methods.map((e) => e.name))
      ..addAll(clazz.accessors.map((e) => e.name))
      ..addAll(((annotation.exclude ?? []) as Iterable<Symbol>)
          .map((e) => MirrorSystem.getName(e)));
    final ClassElement templateElement = type.element;
    handleTemplate(
        clazz, accessor.name, templateElement, genericsMapping, excludes,
        (name, code) {
      excludes.add(name);
      transformer.insertAt(classNode.end - 1, code);
    });
  }

  String formatParameter(
      ParameterElement p, Map<DartType, DartType> genericsMapping) {
    final type = substituteTypeToGeneric(genericsMapping, p.type);
    String code = type is FunctionType
        ? formatFunction(type, p.name, genericsMapping)
        : '${type} ${p.name}';
    if (p.defaultValueCode != null) {
      if (p.parameterKind == ParameterKind.POSITIONAL) code += '=';
      if (p.parameterKind == ParameterKind.NAMED) code += ':';
      code += p.defaultValueCode;
    }
    return code;
  }

  String formatFunction(
      FunctionType type, String name, Map<DartType, DartType> genericsMapping) {
    String result = '${type.returnType.displayName} ${name}(';

    final requiredParameters =
        type.parameters.where((p) => p.parameterKind == ParameterKind.REQUIRED);
    final optionalPositionalParameters = type.parameters
        .where((p) => p.parameterKind == ParameterKind.POSITIONAL);
    final optionalNamedParameters =
        type.parameters.where((p) => p.parameterKind == ParameterKind.NAMED);

    result += requiredParameters
        .map((p) => formatParameter(p, genericsMapping))
        .join(', ');

    if (optionalPositionalParameters.isNotEmpty) {
      if (requiredParameters.isNotEmpty) result += ', ';
      result += '[';
      result += optionalPositionalParameters
          .map((p) => formatParameter(p, genericsMapping))
          .join(', ');
      result += ']';
    }

    if (optionalNamedParameters.isNotEmpty) {
      if (requiredParameters.isNotEmpty) result += ', ';
      result += '{';
      result += optionalNamedParameters
          .map((p) => formatParameter(p, genericsMapping))
          .join(', ');
      result += '}';
    }

    result += ')';
    return result;
  }

  void handleTemplate(
      ClassElement clazz,
      String targetName,
      ClassElement templateElement,
      Map<DartType, DartType> genericsMapping,
      Iterable<String> excludes,
      void addMember(String displayName, String code)) {
    String replaceTypeToGeneric(DartType e) =>
        substituteTypeToGeneric(genericsMapping, e).displayName;

    for (final accessor in templateElement.accessors) {
      final displayName = accessor.displayName + (accessor.isSetter ? '=' : '');
      if (accessor.isPrivate) continue;
      if (excludes.contains(displayName)) continue;

      String code = '';
      if (accessor.isSetter) {
        if (accessor.returnType.isVoid) code += 'void ';
        code +=
            'set ${accessor.displayName}(${formatParameter(accessor.parameters.first, genericsMapping)}) { ${mayPrefixByThis(targetName, accessor.parameters)}.${accessor.displayName} = ${accessor.parameters.first.name}; }';
      } else if (accessor.isGetter) {
        code +=
            '${replaceTypeToGeneric(accessor.returnType)} get ${accessor.displayName} => ${mayPrefixByThis(targetName, accessor.parameters)}.${accessor.displayName};';
      }
      addMember(displayName, code);
    }

    for (final method in templateElement.methods) {
      if (method.isPrivate) continue;
      if (excludes.contains(method.displayName)) continue;

      final requiredParameters = method.parameters
          .where((p) => p.parameterKind == ParameterKind.REQUIRED);
      String parametersDeclaration = requiredParameters
          .map((p) => formatParameter(p, genericsMapping))
          .join(', ');
      String parametersCall = requiredParameters.map((e) => e.name).join(', ');

      final optionalPositionalParameters = method.parameters
          .where((p) => p.parameterKind == ParameterKind.POSITIONAL);
      if (optionalPositionalParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
          parametersCall += ', ';
        }
        parametersDeclaration += '[';
        parametersDeclaration += optionalPositionalParameters
            .map((p) => formatParameter(p, genericsMapping))
            .join(', ');
        parametersDeclaration += ']';
        parametersCall +=
            optionalPositionalParameters.map((e) => e.name).join(', ');
      }

      final optionalNamedParameters = method.parameters
          .where((p) => p.parameterKind == ParameterKind.NAMED);
      if (optionalNamedParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
          parametersCall += ', ';
        }
        parametersDeclaration += '{';
        parametersDeclaration += optionalNamedParameters
            .map((p) => formatParameter(p, genericsMapping))
            .join(', ');
        parametersDeclaration += '}';
        parametersCall += optionalNamedParameters
            .map((e) => '${e.name}: ${e.name}')
            .join(', ');
      }

      final returnType = method.returnType;
      String methodSignature = '${method.displayName}($parametersDeclaration)';
      String delegateCall =
          '${mayPrefixByThis(targetName, method.parameters)}.${method.displayName}($parametersCall)';
      if (method.isOperator) {
        methodSignature =
            'operator ${method.displayName}($parametersDeclaration)';
        delegateCall =
            '${mayPrefixByThis(targetName, method.parameters)} ${method.displayName} $parametersCall';
        if (method.displayName == '[]') {
          final parameter = requiredParameters.map((e) => e.name).first;
          delegateCall =
              '${mayPrefixByThis(targetName, method.parameters)}[$parameter]';
        }
        if (method.displayName == '[]=') {
          final parameters = requiredParameters.map((e) => e.name).toList();
          delegateCall =
              '${mayPrefixByThis(targetName, method.parameters)}[${parameters[0]}] = ${parameters[1]}';
        }
      }

      String code = '';
      if (returnType.isVoid) {
        code += 'void $methodSignature { $delegateCall; }';
      } else {
        code +=
            '${replaceTypeToGeneric(returnType)} $methodSignature => $delegateCall;';
      }
      addMember(method.displayName, code);
    }

    // go to inherited types
    final inheritedTypes = <InterfaceType>[];
    inheritedTypes.addAll(templateElement.interfaces);
    inheritedTypes.addAll(templateElement.mixins);
    inheritedTypes.add(templateElement.supertype);
    inheritedTypes.forEach((interfaceType) {
      if (interfaceType == null) return;
      final newGenericsMapping = new Map<DartType, DartType>.fromIterable(
          new Iterable.generate(interfaceType.element.typeParameters.length),
          key: (int i) => interfaceType.element.typeParameters[i].type,
          value: (int i) {
        final t = interfaceType.typeArguments[i];
        return t is TypeParameterType ? genericsMapping[t] : t;
      });
      handleTemplate(clazz, targetName, interfaceType.element,
          newGenericsMapping, excludes, addMember);
    });
  }

  /// Returns the [name] or the [name] prefixed by `this.` if a parameter has this
  /// [name].
  String mayPrefixByThis(String name, List<ParameterElement> parameters) =>
      parameters.map((p) => p.displayName).any((n) => n == name)
          ? 'this.$name'
          : name;

  DartType substituteTypeToGeneric(
      Map<DartType, DartType> genericsMapping, DartType type) {
    if (type is InterfaceType) {
      if (type.typeParameters.isNotEmpty) {
        final argumentsTypes = type.typeArguments
            .map((e) => substituteTypeToGeneric(genericsMapping, e))
            .toList();

        // http://dartbug.com/19253
        //        final t = type.substitute4(argumentsTypes);
        //        return t;

        final newType = new InterfaceTypeImpl(type.element);
        newType.typeArguments = argumentsTypes;
        return newType;
      } else {
        return type;
      }
    }
    if (type is FunctionType) {
      return type.substitute3(type.typeArguments
          .map((e) => substituteTypeToGeneric(genericsMapping, e))
          .toList());
    }
    if (type is TypeParameterType) {
      if (genericsMapping.containsKey(type)) return genericsMapping[type];
      if (type.element.bound == null) return DynamicTypeImpl.instance;
      return type.element.bound;
    }
    return type;
  }
}
