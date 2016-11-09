// Copyright (c) 2015, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

import 'dart:async';
import 'dart:mirrors';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:source_gen/src/utils.dart';
import 'package:zengen/zengen.dart';
import 'package:zengen_generator/src/incremental_generator.dart';
import 'package:zengen_generator/src/util.dart';

final _zengenLibName = 'zengen';

class ZengenGenerator extends IncrementalGenerator {
  final List<ContentModifier> modifiers = <ContentModifier>[
    new ImplementationContentModifier(),
    new ValueContentModifier(),
    new DefaultConstructorContentModifier(),
    new ToStringContentModifier(),
    new EqualsAndHashCodeContentModifier(),
    new DelegateContentModifier(),
    new LazyContentModifier(),
    new CachedContentModifier(),
  ];

  ZengenGenerator();

  @override
  Future<String> generateForLibraryElement(LibraryElement library, _) async {
    final genPart = getGeneratedPart(library);
    final elements = getElementsFromLibraryElement(library);

    // first step : copy all template element and unprivate them into part
    String content = '';
    final handledElements =
        elements.where((e) => modifiers.any((modifier) => modifier.accept(e)));
    for (final element
        in handledElements.where((e) => !hasAnnotation(e, GeneratedFrom))) {
      if (element.unit == genPart) continue;
      if (element is ClassElement) {
        // remove leading '_' of Class name
        final newClassName = element.displayName.substring(1);

        // skip if already generated
        if (elements.any((e) => e is ClassElement && e.name == newClassName))
          continue;

        // check that template is private
        if (element.isPublic) throw 'The template $element must be private';

        // generate
        final classNode = element.computeNode() as ClassDeclaration;
        final transformer = new Transformer();
        transformer.insertAt(
            classNode.offset, '@GeneratedFrom(${element.displayName})');
        transformer.replace(
            classNode.name.offset, classNode.name.end, newClassName);

        for (final constr
            in classNode.members.where((e) => e is ConstructorDeclaration)) {
          final returnType = (constr as ConstructorDeclaration).returnType;
          transformer.replace(returnType.offset, returnType.end, newClassName);
        }
        content += transformer.applyOnCode(
            element.context
                .getContents(element.source)
                .data
                .substring(classNode.offset, classNode.end),
            initialPadding: -classNode.offset);
      }
    }
    if (content.isNotEmpty) return content;

    // init content with part content
    content = genPart.context.getContents(genPart.source).data;

    // find the first matching element to refine
    for (final element
        in handledElements.where((e) => hasAnnotation(e, GeneratedFrom))) {
      for (final modifier in modifiers) {
        if (!modifier.accept(element)) continue;
        final transformer = new Transformer();
        modifier.visit(element, transformer);
        if (transformer.hasTransformations) {
          content = transformer.applyOnCode(content);
          return content;
        }
      }
    }
    return content;
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
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    final classNode = clazz.computeNode();
    final annotation = getAnnotation(clazz, ToString) as ToString;

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
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    final classNode = clazz.computeNode();
    final annotation =
        getAnnotation(clazz, EqualsAndHashCode) as EqualsAndHashCode;

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

    if (!clazz.methods.any((m) => m.name == '==')) {
      transformer.insertAt(classNode.end - 1, equals);
    }
    if (!clazz.accessors.any((m) => m.name == 'hashCode')) {
      transformer.insertAt(classNode.end - 1, hashCode);
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
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    clazz.constructors.where(acceptConstructor).forEach(
        (constructor) => replaceConstructor(clazz, transformer, constructor));
  }

  void replaceConstructor(ClassElement clazz, Transformer transformer,
      ConstructorElement constructor) {
    final annotation =
        getAnnotation(constructor, DefaultConstructor) as DefaultConstructor;

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
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    final classNode = clazz.computeNode();
    final annotation = getAnnotation(clazz, Value) as Value;

    getAnnotations(classNode, Value).forEach((e) => transformer.removeNode(e));

    if (!hasAnnotation(clazz, ToString)) {
      transformer.insertAt(classNode.offset, '@ToString()');
    }
    if (!hasAnnotation(clazz, EqualsAndHashCode)) {
      transformer.insertAt(classNode.offset, '@EqualsAndHashCode()');
    }

    if (clazz.constructors.length == 1 &&
        clazz.constructors.single.isDefaultConstructor &&
        clazz.constructors.single.isSynthetic) {
      transformer.insertAt(
          classNode.end - 1,
          '@DefaultConstructor(useConst:${annotation.useConst}) '
          'external ${clazz.name}();');
    } else {
      clazz.constructors
          .where((constructor) =>
              constructor.isExternal &&
              !hasAnnotation(constructor, DefaultConstructor))
          .forEach((constructor) {
        transformer.insertAt(constructor.computeNode().offset,
            '@DefaultConstructor(useConst:${annotation.useConst})');
      });
    }
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
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    clazz.accessors
        .where(acceptAccessor)
        .forEach((accessor) => generateMembers(clazz, transformer, accessor));
  }

  void generateMembers(ClassElement clazz, Transformer transformer,
      PropertyAccessorElement accessor) {
    final classNode = clazz.computeNode() as ClassDeclaration;
    final annotation = getAnnotation(
            accessor.isSynthetic ? accessor.variable : accessor, Delegate)
        as Delegate;
    final type = accessor.returnType;

    //add implements
    if (annotation.addImplements) {
      if (classNode.implementsClause == null) {
        transformer.insertAt(classNode.leftBracket.offset, ' implements $type');
      } else if (classNode.implementsClause.interfaces
          .every((i) => i.type != type)) {
        transformer.insertAt(classNode.implementsClause.end, ', $type');
      }
    }

    // remove @Delegate
    final annotations = getAnnotations(
        (accessor.isSynthetic
            ? ((accessor.variable.computeNode() as VariableDeclaration).parent
                    as VariableDeclarationList)
                .parent
            : accessor.computeNode()) as AnnotatedNode,
        Delegate);
    for (final annotation in annotations) {
      transformer.removeNode(annotation);
    }

    final genericsMapping = <DartType, DartType>{};
    if (type is ParameterizedType) {
      for (var i = 0; i < type.typeParameters.length; i++) {
        genericsMapping[type.typeParameters[i].type] = type.typeArguments[i];
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
      ..addAll((annotation.exclude ?? <Symbol>[])
          .map((e) => MirrorSystem.getName(e)));
    final templateElement = type.element as ClassElement;
    visitInheritedMembers(
        clazz, accessor.name, templateElement, genericsMapping, excludes,
        (name, code) {
      excludes.add(name);
      transformer.insertAt(classNode.end - 1, code);
    });
  }

  void visitInheritedMembers(
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
      if (accessor.isStatic) continue;
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
      if (method.isStatic) continue;
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
      visitInheritedMembers(clazz, targetName, interfaceType.element,
          newGenericsMapping, excludes, addMember);
    });
  }
}

class LazyContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && element.accessors.any(acceptAccessor);

  static bool acceptAccessor(PropertyAccessorElement accessor) =>
      !accessor.isStatic &&
      accessor.isSynthetic &&
      hasAnnotation(accessor.variable, Lazy);

  @override
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    transformer.insertAt(clazz.computeNode().end - 1,
        'final _lazyFields = <Symbol, dynamic>{};');
    clazz.accessors
        .where(acceptAccessor)
        .forEach((accessor) => generateMembers(clazz, transformer, accessor));
    clazz.accessors
        .where(acceptAccessor)
        .map((accessor) => accessor.variable.computeNode().parent.parent)
        .toSet()
        .forEach(transformer.removeNode);
  }

  void generateMembers(ClassElement clazz, Transformer transformer,
      PropertyAccessorElement accessor) {
    final field = accessor.variable.computeNode() as VariableDeclaration;
    final declaration = field.parent.parent;
    final type = accessor.variable.type;
    final name = accessor.variable.name;
    final value = field.initializer;
    if (value == null) {
      throw 'The lazy field $name in $clazz must have an initializer.';
    }
    if (accessor.isGetter) {
      transformer.insertAt(declaration.offset,
          '$type get $name => _lazyFields.putIfAbsent(#$name, () => $value);');
    }
    if (accessor.isSetter) {
      transformer.insertAt(
          declaration.offset, 'set $name($type v) => _lazyFields[#$name] = v;');
    }
  }
}

class CachedContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && element.methods.any(acceptMethod);

  bool acceptMethod(MethodElement method) =>
      !method.isAbstract && !method.isStatic && hasAnnotation(method, Cached);

  @override
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    final classNode = clazz.computeNode() as ClassDeclaration;
    transformer.insertAt(
        classNode.end - 1, 'final _caches = <Symbol, Cache> {};');

    if (!clazz.methods.any((m) => m.name == '_createCache')) {
      transformer.insertAt(
          classNode.end - 1,
          'Cache _createCache(Symbol methodName, Function compute)'
          '=> new Cache(compute);');
    }
    clazz.methods
        .where(acceptMethod)
        .forEach((method) => generateMembers(clazz, transformer, method));
  }

  void generateMembers(
      ClassElement clazz, Transformer transformer, MethodElement method) {
    final methodNode = method.computeNode();

    // remove @Cached annotation
    getAnnotations(methodNode, Cached)
        .forEach((e) => transformer.removeNode(e));

    // TODO(aa) inject content
    final libContent = clazz.context.getContents(clazz.source).data;

    // build initFn
    String initFn =
        libContent.substring(methodNode.name.end, methodNode.end).trim();
    if (initFn.endsWith(';')) initFn = initFn.substring(0, initFn.length - 1);

    // build parameter for call
    String parameters = '[]';
    if (method.parameters != null) {
      final requiredParameters = method.parameters
              ?.where((p) => p.parameterKind == ParameterKind.REQUIRED) ??
          [];
      final optionalPositionalParameters = method.parameters
              ?.where((p) => p.parameterKind == ParameterKind.POSITIONAL) ??
          [];
      final optionalNamedParameters = method.parameters
              ?.where((p) => p.parameterKind == ParameterKind.NAMED) ??
          [];
      final positionalParameters = []
        ..addAll(requiredParameters)
        ..addAll(optionalPositionalParameters);

      parameters = '[';
      parameters += positionalParameters.map((p) => p.name).join(', ');
      parameters += ']';
      if (optionalNamedParameters.isNotEmpty) {
        parameters += ', ';
        parameters += '{';
        parameters += optionalNamedParameters
            .map((p) => '#' + p.name + ': ' + p.name)
            .join(', ');
        parameters += '}';
      }
    }

    // add transformation
    transformer.replace(
        methodNode.parameters.end,
        methodNode.end,
        '=> _caches.putIfAbsent(#${method.name}, '
            '() => _createCache(#${method.name}, ${initFn}))'
            '.getValue($parameters)' +
            (methodNode.returnType == null ||
                    methodNode.returnType.type.isDynamic
                ? ';'
                : 'as ${methodNode.returnType};'));
  }
}

class ImplementationContentModifier implements ContentModifier {
  @override
  bool accept(Element element) =>
      element is ClassElement && element.methods.any(acceptMethod);

  static bool acceptMethod(MethodElement method) =>
      !method.isStatic && hasAnnotation(method, Implementation);

  @override
  void visit(Element element, Transformer transformer) {
    final clazz = element as ClassElement;
    final classNode = clazz.computeNode() as ClassDeclaration;
    if (classNode.abstractKeyword != null) {
      transformer.removeToken(classNode.abstractKeyword);
    }
    clazz.methods
        .where(acceptMethod)
        .forEach((method) => generateMembers(clazz, transformer, method));
  }

  void generateMembers(
      ClassElement clazz, Transformer transformer, MethodElement method) {
    final classNode = clazz.computeNode() as ClassDeclaration;

    // remove @Implementation
    getAnnotations(method.computeNode(), Implementation)
        .forEach(transformer.removeNode);

    final genericsMapping = clazz.typeParameters == null
        ? <DartType, DartType>{}
        : new Map<DartType, DartType>.fromIterables(
            clazz.typeParameters.map((e) => e.type), clazz.type.typeArguments);
    final excludes = <String>[];
    visitAbstractMembers(clazz, method.name, clazz, genericsMapping, excludes,
        (displayName, code, [node]) {
      excludes.add(displayName);
      if (node != null) {
        transformer.replace(node.offset, node.end, code);
      } else {
        transformer.insertAt(classNode.end - 1, code);
      }
    });
  }

  void visitAbstractMembers(
      ClassElement clazz,
      String targetName,
      ClassElement templateElement,
      Map<DartType, DartType> genericsMapping,
      List<String> excludes,
      void addMember(String displayName, String code, [AstNode node]),
      {bool isInterface: false}) {
    String replaceTypeToGeneric(DartType e) =>
        substituteTypeToGeneric(genericsMapping, e).displayName;

    for (final accessor in templateElement.accessors) {
      final displayName = accessor.displayName + (accessor.isSetter ? '=' : '');
      if (accessor.isPrivate) continue;
      if (!isInterface && !accessor.isAbstract) {
        excludes.add(displayName);
      }
      //if (isMemberAlreadyDefined(clazz, displayName)) continue;
      if (excludes.contains(displayName)) continue;

      String code = '';
      if (accessor.isSetter) {
        if (accessor.returnType.isVoid) code += 'void ';
        code +=
            'set ${accessor.displayName}(${formatParameter(accessor.parameters.first, genericsMapping)}) '
            "{ ${mayPrefixByThis(targetName, accessor.parameters)}(new StringInvocation('${accessor.displayName}', isSetter: true, positionalArguments: [${accessor.parameters.first.name}])); }";
      } else if (accessor.isGetter) {
        final returnType = replaceTypeToGeneric(accessor.returnType);
        code += '$returnType get ${accessor.displayName} => '
            "${mayPrefixByThis(targetName, accessor.parameters)}(new StringInvocation('${accessor.displayName}', isGetter: true))" +
            (returnType == 'dynamic' ? ';' : ' as $returnType;');
      }
      addMember(displayName, code,
          clazz == templateElement ? accessor.computeNode() : null);
    }

    for (final method in templateElement.methods) {
      if (method.isPrivate) continue;
      if (!isInterface && !method.isAbstract) {
        excludes.add(method.displayName);
      }
      //if (isMemberAlreadyDefined(clazz, method.displayName)) continue;
      if (excludes.contains(method.displayName)) continue;

      final requiredParameters = method.parameters
          .where((p) => p.parameterKind == ParameterKind.REQUIRED);
      final optionalPositionalParameters = method.parameters
          .where((p) => p.parameterKind == ParameterKind.POSITIONAL);
      final optionalNamedParameters = method.parameters
          .where((p) => p.parameterKind == ParameterKind.NAMED);

      String parametersDeclaration = requiredParameters
          .map((p) => formatParameter(p, genericsMapping))
          .join(', ');

      if (optionalPositionalParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
        }
        parametersDeclaration += '[';
        parametersDeclaration += optionalPositionalParameters
            .map((p) => formatParameter(p, genericsMapping))
            .join(', ');
        parametersDeclaration += ']';
      }

      if (optionalNamedParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
        }
        parametersDeclaration += '{';
        parametersDeclaration += optionalNamedParameters
            .map((p) => formatParameter(p, genericsMapping))
            .join(', ');
        parametersDeclaration += '}';
      }

      String stringInvocation =
          "new StringInvocation('${method.name}', isMethod: true";
      if (requiredParameters.isNotEmpty ||
          optionalPositionalParameters.isNotEmpty) {
        final parameters = (<ParameterElement>[]
              ..addAll(requiredParameters)
              ..addAll(optionalPositionalParameters))
            .map((e) => e.name);
        stringInvocation += ', positionalArguments: [${parameters.join(', ')}]';
      }
      if (optionalNamedParameters.isNotEmpty) {
        stringInvocation += ', namedArguments: {' +
            optionalNamedParameters
                .map((e) => "'${e.name}': ${e.name}")
                .join(', ') +
            '}';
      }
      stringInvocation += ')';

      final returnType = method.returnType;
      String methodSignature = '${method.displayName}($parametersDeclaration)';
      String delegateCall =
          '${mayPrefixByThis(targetName, method.parameters)}($stringInvocation)';
      if (method.isOperator) {
        methodSignature =
            'operator ${method.displayName}($parametersDeclaration)';
      }

      String code = '';
      if (returnType.isVoid) {
        code += 'void $methodSignature { $delegateCall; }';
      } else {
        final type = replaceTypeToGeneric(returnType);
        code += '$type $methodSignature => $delegateCall' +
            (type == 'dynamic' ? ';' : ' as $type;');
      }
      addMember(method.displayName, code,
          clazz == templateElement ? method.computeNode() : null);
    }

    // go through inherited types
    // mixins are proceeded after because a parent can implements an abstract method in mixin
    reapplyWith(InterfaceType interfaceType, bool isInterface) {
      if (interfaceType == null) return;
      final newGenericsMapping = new Map<DartType, DartType>.fromIterable(
          new Iterable.generate(interfaceType.element.typeParameters.length),
          key: (int i) => interfaceType.element.typeParameters[i].type,
          value: (int i) {
        final t = interfaceType.typeArguments[i];
        return t is TypeParameterType ? genericsMapping[t] : t;
      });
      visitAbstractMembers(clazz, targetName, interfaceType.element,
          newGenericsMapping, excludes, addMember,
          isInterface: isInterface);
    }

    reapplyWith(templateElement.supertype, isInterface);
    templateElement.mixins.forEach((e) => reapplyWith(e, isInterface));
    templateElement.interfaces.forEach((e) => reapplyWith(e, true));
  }
}
