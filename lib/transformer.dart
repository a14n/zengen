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
  new ToStringAppender(), //
  new EqualsAndHashCodeAppender(), //
  new DelegateAppender(), //
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
    if (!node.isGetter) return;
    _transform(node, node.parent, node.returnType, node.name.name);
  }

  @override
  visitFieldDeclaration(FieldDeclaration node) => _transform(node, node.parent,
      node.fields.type, node.fields.variables.first.name.name);

  _transform(Declaration node, ClassDeclaration clazz, TypeName typeName, String
      targetName) {
    final delegates = getAnnotations(node, 'Delegate');
    if (delegates.isEmpty) return;

    final index = node.parent.end - 1;
    for (final delegate in delegates) {
      final excludes = getExcludes(delegate);
      final ClassElement templateElement = typeName.type.element;
      final genericsMapping = typeName.typeArguments == null ? <String, String>
          {} : new Map<String, String>.fromIterables(templateElement.typeParameters.map(
          (e) => e.displayName), typeName.typeArguments.arguments.map((e) => e.name.name)
          );
      handleTemplate(clazz, targetName, templateElement, genericsMapping,
          excludes, (displayName, code) {
        excludes.add(displayName);
        transformations.add(new Transformation.insertion(index, '  $code\n'));
      });
    }
  }

  void handleTemplate(ClassDeclaration clazz, String targetName, ClassElement
      templateElement, Map<String, String> genericsMapping, List<String>
      excludes, void addMember(String displayName, String code)) {

    substituteTypeToGeneric(DartType e) => this.substituteTypeToGeneric(
        genericsMapping, e);
    substituteParameterToGeneric(ParameterElement e) =>
        this.substituteTypeToGeneric(genericsMapping, e.type) + ' ' + e.name;

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
            '${substituteTypeToGeneric(accessor.returnType)} get ${accessor.displayName} => ${mayPrefixByThis(targetName, accessor.parameters)}.${accessor.displayName};';

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
            '${substituteTypeToGeneric(returnType)} $methodSignature => $delegateCall;';
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
      final newGenericsMapping = new Map<String, String>.fromIterable(
          new Iterable.generate(interfaceType.element.typeParameters.length), key: (int i)
          => interfaceType.element.typeParameters[i].name, value: (int i) {
        final t = interfaceType.typeArguments[i];
        return t is TypeParameterType ? genericsMapping[t.name] : t.name;
      });
      handleTemplate(clazz, targetName, interfaceType.element,
          newGenericsMapping, excludes, addMember);
    });
  }

  String substituteTypeToGeneric(Map<String, String> genericsMapping, DartType
      e) {
    if (e is InterfaceType) {
      if (e.typeParameters.isNotEmpty) {
        final types = e.typeArguments.map((e) => substituteTypeToGeneric(
            genericsMapping, e));
        return '${e.name}<${types.join(', ')}>';
      } else {
        return e.name;
      }
    }
    if (e is TypeParameterType) {
      if (genericsMapping[e.name] != null) return genericsMapping[e.name];
      if (e.element.bound == null) return 'dynamic';
      return e.element.bound.displayName;
    }
    return e.name;
  }


  mayPrefixByThis(String targetName, List<ParameterElement> parameters) =>
      parameters.map((p) => p.displayName).any((name) => name == targetName) ?
      'this.$targetName' : targetName;

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

isMemberAlreadyDefined(ClassDeclaration clazz, String name) =>
    clazz.members.any((m) => (m is MethodDeclaration && m.name.name + (m.isSetter ?
    '=' : '') == name) || (m is FieldDeclaration && m.fields.variables.any((f) =>
    f.name.name == name)) || (m is ConstructorDeclaration && m.name.name == name));

const _LIBRARY_NAME = 'zengen';

Iterable<Annotation> getAnnotations(Declaration declaration, String name) =>
    declaration.metadata.where((m) => m.element.library.name == _LIBRARY_NAME &&
    m.element is ConstructorElement && m.element.enclosingElement.name == name);

bool isMethodDefined(ClassDeclaration clazz, String methodName) =>
    clazz.members.any((m) => m is MethodDeclaration && m.name.name == methodName);
