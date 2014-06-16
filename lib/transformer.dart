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

import 'dart:async' show Future, Completer;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/resolver.dart';

import 'package:zengen/zengen.dart';

const DELEGATE_EXCLUDES = const <String>['hashCode', 'runtimeType', '==',
    'toString', 'noSuchMethod'];

final MODIFIERS = <ContentModifier>[//
  new ImplementationModifier(), //
  new DefaultConstructorModifier(), //
  new ToStringAppender(), //
  new EqualsAndHashCodeAppender(), //
  new DelegateAppender(), //
  new LazyModifier(), //
  new ValueModifier(), //
];

abstract class ContentModifier {
  List<Transformation> accept(CompilationUnitElement unitElement);
}

class ZengenTransformer extends TransformerGroup {
  ZengenTransformer.asPlugin() : this._(new ModifierTransformer());
  ZengenTransformer._(ModifierTransformer mt) : super(new Iterable.generate(
      1000, (_) => [mt]));
}

class ModifierTransformer extends Transformer {
  Resolvers resolvers = new Resolvers(dartSdkDirectory);
  List<AssetId> unmodified = [];

  Map<AssetId, String> contentsPending = {};

  ModifierTransformer();

  String get allowedExtensions => ".dart";

  Future apply(Transform transform) {
    final id = transform.primaryInput.id;
    if (unmodified.contains(id)) return new Future.value();
    if (contentsPending.containsKey(id)) {
      transform.addOutput(new Asset.fromString(id, contentsPending.remove(id)));
      return new Future.value();
    }
    return resolvers.get(transform).then((resolver) {
      return new Future(() => applyResolver(transform, resolver)).whenComplete(
          () => resolver.release());
    });
  }

  applyResolver(Transform transform, Resolver resolver) {
    final assetId = transform.primaryInput.id;
    final lib = resolver.getLibrary(assetId);

    if (isPart(lib)) return;

    for (final unit in lib.units) {
      final id = unit.source.assetId;
      final transaction = resolver.createTextEditTransaction(unit);
      traverseModifiers(unit, (List<Transformation> transformations) {
        for (final t in transformations) {
          transaction.edit(t.begin, t.end, t.content);
        }
      });
      if (transaction.hasEdits) {
        final np = transaction.commit();
        np.build('');
        final newContent = np.text;
        transform.logger.fine("new content for $id : \n$newContent", asset: id);
        if (id == assetId) {
          transform.addOutput(new Asset.fromString(id, newContent));
        } else {
          contentsPending[id] = newContent;
        }
      } else {
        unmodified.add(id);
      }
    }
  }

  bool isPart(LibraryElement lib) => lib.unit.directives.any((d) => d is
      PartOfDirective);
}

void traverseModifiers(CompilationUnitElement
    unit, onTransformations(List<Transformation> transformations)) {
  bool modifications = true;
  while (modifications) {
    modifications = false;
    for (final modifier in MODIFIERS) {
      final transformations = modifier.accept(unit);
      if (transformations.isNotEmpty) {
        onTransformations(transformations);
        modifications = true;
        return;
      }
    }
  }
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
  Transformation.deletation(this.begin, this.end) : content = '';
}

class ToStringAppender implements ContentModifier {
  @override
  List<Transformation> accept(CompilationUnitElement unitElement) {
    final transformations = [];
    unitElement.unit.declarations.where((d) => d is ClassDeclaration).where(
        (ClassDeclaration c) => getAnnotations(c, 'ToString').isNotEmpty).forEach(
        (ClassDeclaration clazz) {
      final annotation = getToString(clazz);
      final callSuper = annotation.callSuper == true;
      final exclude = (annotation.exclude == null ? [] :
          annotation.exclude)..add('hashCode');
      final includePrivate = annotation.includePrivate == true;

      final getters = clazz.element.accessors.where((e) => e.isGetter &&
          !e.isStatic && (includePrivate || !e.isPrivate)).map((e) => e.name).where((e) =>
          !exclude.contains(e));

      final toString = '@generated @override String toString() => '
          '"${clazz.name.name}(' + //
      (callSuper ? 'super=\${super.toString()}' : '') + //
      (callSuper && getters.isNotEmpty ? ', ' : '') + //
      getters.map((f) => '$f=\$$f').join(', ') + ')";';

      final index = clazz.end - 1;
      if (!isMethodDefined(clazz, 'toString')) {
        transformations.add(new Transformation.insertion(index, '  $toString\n')
            );
      }
    });
    return transformations;
  }

  ToString getToString(ClassDeclaration clazz) {
    final Annotation annotation = getAnnotations(clazz, 'ToString').first;

    if (annotation == null) return null;

    bool callSuper;
    List<Symbol> exclude;
    bool includePrivate;

    final NamedExpression callSuperPart =
        annotation.arguments.arguments.firstWhere((e) => e is NamedExpression &&
        e.name.label.name == 'callSuper', orElse: () => null);
    if (callSuperPart != null) {
      callSuper = (callSuperPart.expression as BooleanLiteral).value;
    }

    final NamedExpression excludePart =
        annotation.arguments.arguments.firstWhere((e) => e is NamedExpression &&
        e.name.label.name == 'exclude', orElse: () => null);
    if (excludePart != null) {
      exclude = (excludePart.expression as ListLiteral).elements.map(
          (SymbolLiteral sl) => sl.toString().substring(sl.poundSign.length)).toList();
    }

    final NamedExpression includePrivatePart =
        annotation.arguments.arguments.firstWhere((e) => e is NamedExpression &&
        e.name.label.name == 'includePrivate', orElse: () => null);
    if (includePrivatePart != null) {
      includePrivate = (includePrivatePart.expression as BooleanLiteral).value;
    }

    return new ToString(callSuper: callSuper, exclude: exclude, includePrivate:
        includePrivate);
  }
}

class EqualsAndHashCodeAppender implements ContentModifier {
  @override
  List<Transformation> accept(CompilationUnitElement unitElement) {
    final transformations = [];
    unitElement.unit.declarations.where((d) => d is ClassDeclaration).where(
        (ClassDeclaration c) => getAnnotations(c, 'EqualsAndHashCode').isNotEmpty
        ).forEach((ClassDeclaration clazz) {
      final annotation = getEqualsAndHashCode(clazz);
      final callSuper = annotation.callSuper == true;
      final exclude = (annotation.exclude == null ? [] :
          annotation.exclude)..add('hashCode');
      final includePrivate = annotation.includePrivate == true;

      final getters = clazz.element.accessors.where((e) => e.isGetter &&
          !e.isStatic && (includePrivate || !e.isPrivate)).map((e) => e.name).where((e) =>
          !exclude.contains(e));

      final hashCodeValues = getters.toList();
      if (callSuper) hashCodeValues.insert(0, 'super.hashCode');
      final hashCode = '@generated @override int get hashCode => '
          'hashObjects([' + hashCodeValues.join(', ') + ']);';

      final equals =
          '@generated @override bool operator ==(o) => identical(this, o) || '
          'o.runtimeType == runtimeType' + (callSuper ? ' && super == o' : '') +
          getters.map((f) => ' && o.$f == $f').join() + ';';

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

  EqualsAndHashCode getEqualsAndHashCode(ClassDeclaration clazz) {
    final Annotation annotation = getAnnotations(clazz, 'EqualsAndHashCode'
        ).first;

    if (annotation == null) return null;

    bool callSuper;
    List<Symbol> exclude;
    bool includePrivate;

    final NamedExpression callSuperPart =
        annotation.arguments.arguments.firstWhere((e) => e is NamedExpression &&
        e.name.label.name == 'callSuper', orElse: () => null);
    if (callSuperPart != null) {
      callSuper = (callSuperPart.expression as BooleanLiteral).value;
    }

    final NamedExpression excludePart =
        annotation.arguments.arguments.firstWhere((e) => e is NamedExpression &&
        e.name.label.name == 'exclude', orElse: () => null);
    if (excludePart != null) {
      exclude = (excludePart.expression as ListLiteral).elements.map(
          (SymbolLiteral sl) => sl.toString().substring(sl.poundSign.length)).toList();
    }

    final NamedExpression includePrivatePart =
        annotation.arguments.arguments.firstWhere((e) => e is NamedExpression &&
        e.name.label.name == 'includePrivate', orElse: () => null);
    if (includePrivatePart != null) {
      includePrivate = (includePrivatePart.expression as BooleanLiteral).value;
    }

    return new EqualsAndHashCode(callSuper: callSuper, exclude: exclude,
        includePrivate: includePrivate);
  }
}

class DelegateAppender extends GeneralizingAstVisitor implements ContentModifier
    {
  final transformations = [];

  @override
  List<Transformation> accept(CompilationUnitElement unitElement) {
    transformations.clear();
    unitElement.unit.visitChildren(this);
    return transformations;
  }

  @override visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    if (!node.isGetter) return;
    _transform(node, node.parent, node.returnType, node.name.name);
  }

  @override
  visitFieldDeclaration(FieldDeclaration node) {
    super.visitFieldDeclaration(node);
    _transform(node, node.parent, node.fields.type,
        node.fields.variables.first.name.name);
  }

  _transform(Declaration node, ClassDeclaration clazz, TypeName typeName, String
      targetName) {
    final delegates = getAnnotations(node, 'Delegate');
    if (delegates.isEmpty) return;

    for (final delegate in delegates) {
      final excludes = getExcludes(delegate);
      final ClassElement templateElement = typeName.type.element;
      final genericsMapping = typeName.typeArguments == null ? <DartType,
          DartType> {} : new Map<DartType, DartType>.fromIterables(
          templateElement.typeParameters.map((e) => e.type),
          typeName.typeArguments.arguments.map((e) => e.type));
      handleTemplate(clazz, targetName, templateElement, genericsMapping,
          excludes, (displayName, code) {
        excludes.add(displayName);
        transformations.add(new Transformation.insertion(clazz.end - 1,
            '  $code\n'));
      });
    }
  }

  void handleTemplate(ClassDeclaration clazz, String targetName, ClassElement
      templateElement, Map<DartType, DartType> genericsMapping, List<String>
      excludes, void addMember(String displayName, String code)) {
    String replaceTypeToGeneric(DartType e) {
      final type = substituteTypeToGeneric(genericsMapping, e);
      if (type is FunctionType) {
        //return formatFunction(type);
        throw 'No name for function';
      } else {
        return type.displayName;
      }
    }
    String substituteParameterToGeneric(ParameterElement e) {
      final type = substituteTypeToGeneric(genericsMapping, e.type);
      if (e.type is FunctionType) {
        return formatFunction(type, e.name);
      } else {
        return type.displayName + ' ' + e.name;
      }
    }

    for (final accessor in templateElement.accessors) {
      final displayName = accessor.displayName + (accessor.isSetter ? '=' : '');
      if (accessor.isPrivate) continue;
      if (isMemberAlreadyDefined(clazz, displayName)) continue;
      if (excludes.contains(displayName)) continue;

      String code = '@generated ';
      if (accessor.isSetter) {
        if (accessor.returnType.isVoid) code += 'void ';
        code +=
            'set ${accessor.displayName}(${substituteParameterToGeneric(accessor.parameters.first)}) { ${mayPrefixByThis(targetName, accessor.parameters)}.${accessor.displayName} = ${accessor.parameters.first.name}; }';
      } else if (accessor.isGetter) {
        code +=
            '${replaceTypeToGeneric(accessor.returnType)} get ${accessor.displayName} => ${mayPrefixByThis(targetName, accessor.parameters)}.${accessor.displayName};';

      }
      addMember(displayName, code);
    }

    for (final method in templateElement.methods) {
      if (method.isPrivate) continue;
      if (isMemberAlreadyDefined(clazz, method.displayName)) continue;
      if (excludes.contains(method.displayName)) continue;

      final requiredParameters = method.parameters.where((p) => p.parameterKind
          == ParameterKind.REQUIRED);
      String parametersDeclaration = requiredParameters.map(
          substituteParameterToGeneric).join(', ');
      String parametersCall = requiredParameters.map((e) => e.name).join(', ');

      final optionalPositionalParameters = method.parameters.where((p) =>
          p.parameterKind == ParameterKind.POSITIONAL);
      if (optionalPositionalParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
          parametersCall += ', ';
        }
        parametersDeclaration += '[';
        parametersDeclaration += optionalPositionalParameters.map(
            substituteParameterToGeneric).join(', ');
        parametersDeclaration += ']';
        parametersCall += optionalPositionalParameters.map((e) => e.name).join(
            ', ');
      }

      final optionalNamedParameters = method.parameters.where((p) =>
          p.parameterKind == ParameterKind.NAMED);
      if (optionalNamedParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
          parametersCall += ', ';
        }
        parametersDeclaration += '{';
        parametersDeclaration += optionalNamedParameters.map(
            substituteParameterToGeneric).join(', ');
        parametersDeclaration += '}';
        parametersCall += optionalNamedParameters.map((e) =>
            '${e.name}: ${e.name}').join(', ');
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

      String code = '@generated ';
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
          new Iterable.generate(interfaceType.element.typeParameters.length), key: (int i)
          => interfaceType.element.typeParameters[i].type, value: (int i) {
        final t = interfaceType.typeArguments[i];
        return t is TypeParameterType ? genericsMapping[t] : t;
      });
      handleTemplate(clazz, targetName, interfaceType.element,
          newGenericsMapping, excludes, addMember);
    });
  }

  List<String> getExcludes(Annotation delegate) {
    final NamedExpression excludePart = delegate.arguments.arguments.firstWhere(
        (e) => e is NamedExpression && e.name.label.name == 'exclude', orElse: () =>
        null);
    final excludes = DELEGATE_EXCLUDES.toList();
    if (excludePart != null) {
      excludes.addAll((excludePart.expression as ListLiteral).elements.map(
          (SymbolLiteral sl) => sl.toString().substring(sl.poundSign.length)));
    }
    return excludes;
  }
}

DartType substituteTypeToGeneric(Map<DartType, DartType>
    genericsMapping, DartType type) {
  if (type is InterfaceType) {
    if (type.typeParameters.isNotEmpty) {
      final argumentsTypes = type.typeArguments.map((e) =>
          substituteTypeToGeneric(genericsMapping, e)).toList();

      // http://dartbug.com/19253
      //        final t = type.substitute4(argumentsTypes);
      //        return t;

      final newType = new InterfaceTypeImpl.con1(type.element);
      newType.typeArguments = argumentsTypes;
      return newType;
    } else {
      return type;
    }
  }
  if (type is FunctionType) {
    return type.substitute3(type.typeArguments.map((e) =>
        substituteTypeToGeneric(genericsMapping, e)).toList());
  }
  if (type is TypeParameterType) {
    if (genericsMapping[type] != null) return genericsMapping[type];
    if (type.element.bound == null) return DynamicTypeImpl.instance;
    return type.element.bound;
  }
  return type;
}

/// checks if the target name is one of the parameter names
bool isOneParametersNamedWith(String name, List<ParameterElement> parameters) =>
    parameters.map((p) => p.displayName).any((n) => n == name);

/// Returns the [name] or the [name] prefixed by `this.` if a parameter has this
/// [name].
String mayPrefixByThis(String name, List<ParameterElement> parameters) =>
    isOneParametersNamedWith(name, parameters) ? 'this.$name' : name;

class LazyModifier extends GeneralizingAstVisitor implements ContentModifier {
  final transformations = [];

  @override
  List<Transformation> accept(CompilationUnitElement unitElement) {
    transformations.clear();
    unitElement.unit.visitChildren(this);
    return transformations;
  }

  @override visitClassDeclaration(ClassDeclaration clazz) {
    super.visitClassDeclaration(clazz);
    if (clazz.members.where((e) => e is FieldDeclaration).every((field) =>
        getAnnotations(field, 'Lazy').isEmpty)) return;
    transformations.add(new Transformation.insertion(clazz.end - 1,
        '  @generated final _lazyFields = <Symbol, dynamic>{};\n'));
  }

  @override visitFieldDeclaration(FieldDeclaration field) {
    super.visitFieldDeclaration(field);
    if (getAnnotations(field, 'Lazy').isEmpty) return;
    final ClassDeclaration clazz = field.parent;
    final isFinal = field.fields.isFinal;
    final type = field.fields.type == null ? 'dynamic' :
        field.fields.type.toString();
    for (final variable in field.fields.variables) {
      final name = variable.name.name;
      final value = variable.initializer;
      if (value == null) {
        throw 'The lazy field $name in $clazz must have an initializer.';
      }
      transformations.add(new Transformation.insertion(field.offset,
          '\n  @generated $type get $name => _lazyFields.putIfAbsent(#$name, () => $value);'
          ));
      if (!isFinal) {
        transformations.add(new Transformation.insertion(field.offset,
            '\n  @generated set $name($type v) => _lazyFields[#$name] = v;'));
      }
    }
    transformations.add(createRemoveTransformation(field));
  }
}

class ImplementationModifier extends GeneralizingAstVisitor implements
    ContentModifier {
  final transformations = [];

  @override
  List<Transformation> accept(CompilationUnitElement unitElement) {
    transformations.clear();
    unitElement.unit.visitChildren(this);
    return transformations;
  }

  @override visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    if (getAnnotations(node, 'Implementation').isEmpty) return;
    _transform(node, node.parent, node.name.name);
  }

  _transform(Declaration node, ClassDeclaration clazz, String targetName) {
    final genericsMapping = clazz.element.typeParameters == null ? <DartType,
        DartType> {} : new Map<DartType, DartType>.fromIterables(
        clazz.element.typeParameters.map((e) => e.type),
        clazz.element.type.typeArguments);
    final excludes = [];
    handleType(clazz, targetName, clazz.element, genericsMapping, excludes,
        (displayName, code, [node]) {
      excludes.add(displayName);
      if (node != null) {
        transformations.add(new Transformation(node.offset, node.end, code));
      } else {
        transformations.add(new Transformation.insertion(clazz.end - 1,
            '  $code\n'));
      }
    });
  }

  void handleType(ClassDeclaration clazz, String targetName, ClassElement
      templateElement, Map<DartType, DartType> genericsMapping, List<String>
      excludes, void addMember(String displayName, String code, [AstNode node]), {bool
      isInterface: false}) {
    String replaceTypeToGeneric(DartType e) {
      final type = substituteTypeToGeneric(genericsMapping, e);
      if (type is FunctionType) {
        //return formatFunction(type);
        throw 'No name for function';
      } else {
        return type.displayName;
      }
    }
    String substituteParameterToGeneric(ParameterElement e) {
      final type = substituteTypeToGeneric(genericsMapping, e.type);
      if (e.type is FunctionType) {
        return formatFunction(type, e.name);
      } else {
        String result = type.displayName + ' ' + e.name;
        if (e.defaultValueRange != null) {
          result += e.parameterKind == ParameterKind.POSITIONAL ? ' = ' : ': ';
          result += e.source.contents.data.substring(e.defaultValueRange.offset,
              e.defaultValueRange.end);
        }
        return result;
      }
    }

    for (final accessor in templateElement.accessors) {
      final displayName = accessor.displayName + (accessor.isSetter ? '=' : '');
      if (accessor.isPrivate) continue;
      if (!isInterface && !accessor.isAbstract) {
        excludes.add(displayName);
      }
      //if (isMemberAlreadyDefined(clazz, displayName)) continue;
      if (excludes.contains(displayName)) continue;

      String code = '@generated ';
      if (accessor.isSetter) {
        if (accessor.returnType.isVoid) code += 'void ';
        code +=
            'set ${accessor.displayName}(${substituteParameterToGeneric(accessor.parameters.first)}) '
            "{ ${mayPrefixByThis(targetName, accessor.parameters)}(new StringInvocation('${accessor.displayName}', isSetter: true, positionalArguments: [${accessor.parameters.first.name}])); }";
      } else if (accessor.isGetter) {
        code +=
            '${replaceTypeToGeneric(accessor.returnType)} get ${accessor.displayName} => '
            "${mayPrefixByThis(targetName, accessor.parameters)}(new StringInvocation('${accessor.displayName}', isGetter: true));";

      }
      addMember(displayName, code, clazz.element == templateElement ?
          accessor.node : null);
    }

    for (final method in templateElement.methods) {
      if (method.isPrivate) continue;
      if (!isInterface && !method.isAbstract) {
        excludes.add(method.displayName);
      }
      //if (isMemberAlreadyDefined(clazz, method.displayName)) continue;
      if (excludes.contains(method.displayName)) continue;

      final requiredParameters = method.parameters.where((p) => p.parameterKind
          == ParameterKind.REQUIRED);
      final optionalPositionalParameters = method.parameters.where((p) =>
          p.parameterKind == ParameterKind.POSITIONAL);
      final optionalNamedParameters = method.parameters.where((p) =>
          p.parameterKind == ParameterKind.NAMED);

      String parametersDeclaration = requiredParameters.map(
          substituteParameterToGeneric).join(', ');

      if (optionalPositionalParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
        }
        parametersDeclaration += '[';
        parametersDeclaration += optionalPositionalParameters.map(
            substituteParameterToGeneric).join(', ');
        parametersDeclaration += ']';
      }

      if (optionalNamedParameters.isNotEmpty) {
        if (requiredParameters.isNotEmpty) {
          parametersDeclaration += ', ';
        }
        parametersDeclaration += '{';
        parametersDeclaration += optionalNamedParameters.map(
            substituteParameterToGeneric).join(', ');
        parametersDeclaration += '}';
      }

      String stringInvocation =
          "new StringInvocation('${method.name}', isMethod: true";
      if (requiredParameters.isNotEmpty ||
          optionalPositionalParameters.isNotEmpty) {
        final parameters = (<ParameterElement>[]
            ..addAll(requiredParameters)
            ..addAll(optionalPositionalParameters)).map((e) => e.name);
        stringInvocation += ', positionalArguments: [${parameters.join(', ')}]';
      }
      if (optionalNamedParameters.isNotEmpty) {
        stringInvocation += ', namedArguments: {' + optionalNamedParameters.map(
            (e) => "'${e.name}': ${e.name}").join(', ') + '}';
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

      String code = '@generated ';
      if (returnType.isVoid) {
        code += 'void $methodSignature { $delegateCall; }';
      } else {
        code +=
            '${replaceTypeToGeneric(returnType)} $methodSignature => $delegateCall;';
      }
      addMember(method.displayName, code, clazz.element == templateElement ?
          method.node : null);
    }

    // go through inherited types
    // mixins are proceeded after because a parent can implements an abstract method in mixin
    reapplyWith(InterfaceType interfaceType, bool isInterface) {
      if (interfaceType == null) return;
      final newGenericsMapping = new Map<DartType, DartType>.fromIterable(
          new Iterable.generate(interfaceType.element.typeParameters.length), key: (int i)
          => interfaceType.element.typeParameters[i].type, value: (int i) {
        final t = interfaceType.typeArguments[i];
        return t is TypeParameterType ? genericsMapping[t] : t;
      });
      handleType(clazz, targetName, interfaceType.element, newGenericsMapping,
          excludes, addMember, isInterface: isInterface);
    }
    reapplyWith(templateElement.supertype, isInterface);
    templateElement.mixins.forEach((e) => reapplyWith(e, isInterface));
    templateElement.interfaces.forEach((e) => reapplyWith(e, true));
  }
}

String formatFunction(FunctionType type, String name) {
  f(ParameterElement p) => p.type is FunctionType ? formatFunction(p.type,
      p.name) : '${p.type} ${p.name}';
  String result = '${type.returnType.displayName} ${name}(';

  final requiredParameters = type.parameters.where((p) => p.parameterKind ==
      ParameterKind.REQUIRED);
  final optionalPositionalParameters = type.parameters.where((p) =>
      p.parameterKind == ParameterKind.POSITIONAL);
  final optionalNamedParameters = type.parameters.where((p) => p.parameterKind
      == ParameterKind.NAMED);

  result += requiredParameters.map(f).join(', ');

  if (optionalPositionalParameters.isNotEmpty) {
    if (requiredParameters.isNotEmpty) result += ', ';
    result += '[';
    result += optionalPositionalParameters.map(f).join(', ');
    result += ']';
  }

  if (optionalNamedParameters.isNotEmpty) {
    if (requiredParameters.isNotEmpty) result += ', ';
    result += '{';
    result += optionalNamedParameters.map(f).join(', ');
    result += '}';
  }

  result += ')';
  return result;
}

class DefaultConstructorModifier extends GeneralizingAstVisitor implements
    ContentModifier {
  final transformations = [];

  @override
  List<Transformation> accept(CompilationUnitElement unitElement) {
    transformations.clear();
    unitElement.unit.visitChildren(this);
    return transformations;
  }

  @override visitClassDeclaration(ClassDeclaration clazz) {
    super.visitClassDeclaration(clazz);
    if (getAnnotations(clazz, 'DefaultConstructor').isEmpty) return;
    if (isMemberAlreadyDefined(clazz, '')) return;

    final Iterable<VariableDeclarationList> fields = clazz.members.where((e) =>
        e is FieldDeclaration && !e.isStatic).map((e) => e.fields);

    final Iterable<VariableDeclaration> requiredVariables = fields.where((e) =>
        e.isFinal).expand((e) => e.variables).where((VariableDeclaration e) =>
        e.initializer == null);
    final mutableVariables = fields.where((e) => !e.isFinal).expand((e) =>
        e.variables);

    var code = '  @generated ';
    code += clazz.name.name + '(';
    code += requiredVariables.map((e) => 'this.${e.name.name}').join(', ');
    if (mutableVariables.isNotEmpty) {
      if (requiredVariables.isNotEmpty) code += ', ';
      code += '{';
      code += mutableVariables.map((e) => 'this.${e.name.name}').join(', ');
      code += '}';
    }
    code += ');\n';

    transformations.add(new Transformation.insertion(clazz.end - 1, code));
  }
}

class ValueModifier extends GeneralizingAstVisitor implements ContentModifier {
  final transformations = [];

  @override
  List<Transformation> accept(CompilationUnitElement unitElement) {
    transformations.clear();
    unitElement.unit.visitChildren(this);
    return transformations;
  }

  @override visitClassDeclaration(ClassDeclaration clazz) {
    super.visitClassDeclaration(clazz);
    if (getAnnotations(clazz, 'Value').isEmpty) return;

    // default constructor
    if (getAnnotations(clazz, 'DefaultConstructor').isEmpty) {
      transformations.add(new Transformation.insertion(clazz.offset,
          '@DefaultConstructor()\n'));
    }

    // hashCode/==
    if (getAnnotations(clazz, 'EqualsAndHashCode').isEmpty) {
      transformations.add(new Transformation.insertion(clazz.offset,
          '@EqualsAndHashCode()\n'));
    }

    // toString
    if (getAnnotations(clazz, 'ToString').isEmpty) {
      transformations.add(new Transformation.insertion(clazz.offset,
          '@ToString()\n'));
    }
  }
}

createRemoveTransformation(AstNode node) => new Transformation.deletation(
    node.offset, node.end);

bool isMemberAlreadyDefined(ClassDeclaration clazz, String name) =>
    clazz.members.any((m) => (m is MethodDeclaration && m.name.name + (m.isSetter ?
    '=' : '') == name) || (m is FieldDeclaration && m.fields.variables.any((f) =>
    f.name.name == name)) || (m is ConstructorDeclaration && (m.name == null &&
    name.isEmpty || m.name != null && m.name.name == name)));

const _LIBRARY_NAME = 'zengen';

Iterable<Annotation> getAnnotations(Declaration declaration, String name) =>
    declaration.metadata.where((m) => m.element.library.name == _LIBRARY_NAME &&
    m.element is ConstructorElement && m.element.enclosingElement.name == name);

bool isMethodDefined(ClassDeclaration clazz, String methodName) =>
    clazz.members.any((m) => m is MethodDeclaration && m.name.name == methodName);
