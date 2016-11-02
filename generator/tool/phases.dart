// Copyright (c) 2016, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:zengen_generator/zengen_generator.dart';

final PhaseGroup phases = new PhaseGroup.singleAction(
    new GeneratorBuilder([
      new ZengenGenerator(),
    ]),
    new InputSet('zengen_generator', const ['example/*.dart']));
