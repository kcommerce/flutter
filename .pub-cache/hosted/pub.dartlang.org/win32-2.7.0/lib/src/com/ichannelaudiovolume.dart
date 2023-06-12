// ichannelaudiovolume.dart

// THIS FILE IS GENERATED AUTOMATICALLY AND SHOULD NOT BE EDITED DIRECTLY.

// ignore_for_file: unused_import, directives_ordering
// ignore_for_file: constant_identifier_names, non_constant_identifier_names
// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../callbacks.dart';
import '../combase.dart';
import '../constants.dart';
import '../exceptions.dart';
import '../guid.dart';
import '../macros.dart';
import '../ole32.dart';
import '../structs.dart';
import '../structs.g.dart';
import '../utils.dart';

import 'iunknown.dart';

/// @nodoc
const IID_IChannelAudioVolume = '{1C158861-B533-4B30-B1CF-E853E51C59B8}';

/// {@category Interface}
/// {@category com}
class IChannelAudioVolume extends IUnknown {
  // vtable begins at 3, is 5 entries long.
  IChannelAudioVolume(super.ptr);

  int GetChannelCount(Pointer<Uint32> pdwCount) => ptr.ref.vtable
          .elementAt(3)
          .cast<
              Pointer<
                  NativeFunction<
                      Int32 Function(Pointer, Pointer<Uint32> pdwCount)>>>()
          .value
          .asFunction<int Function(Pointer, Pointer<Uint32> pdwCount)>()(
      ptr.ref.lpVtbl, pdwCount);

  int SetChannelVolume(
          int dwIndex, double fLevel, Pointer<GUID> EventContext) =>
      ptr.ref.vtable
              .elementAt(4)
              .cast<
                  Pointer<
                      NativeFunction<
                          Int32 Function(Pointer, Uint32 dwIndex, Float fLevel,
                              Pointer<GUID> EventContext)>>>()
              .value
              .asFunction<
                  int Function(Pointer, int dwIndex, double fLevel,
                      Pointer<GUID> EventContext)>()(
          ptr.ref.lpVtbl, dwIndex, fLevel, EventContext);

  int GetChannelVolume(int dwIndex, Pointer<Float> pfLevel) => ptr.ref.vtable
          .elementAt(5)
          .cast<
              Pointer<
                  NativeFunction<
                      Int32 Function(
                          Pointer, Uint32 dwIndex, Pointer<Float> pfLevel)>>>()
          .value
          .asFunction<
              int Function(Pointer, int dwIndex, Pointer<Float> pfLevel)>()(
      ptr.ref.lpVtbl, dwIndex, pfLevel);

  int SetAllVolumes(
          int dwCount, Pointer<Float> pfVolumes, Pointer<GUID> EventContext) =>
      ptr.ref.vtable
              .elementAt(6)
              .cast<
                  Pointer<
                      NativeFunction<
                          Int32 Function(
                              Pointer,
                              Uint32 dwCount,
                              Pointer<Float> pfVolumes,
                              Pointer<GUID> EventContext)>>>()
              .value
              .asFunction<
                  int Function(Pointer, int dwCount, Pointer<Float> pfVolumes,
                      Pointer<GUID> EventContext)>()(
          ptr.ref.lpVtbl, dwCount, pfVolumes, EventContext);

  int GetAllVolumes(int dwCount, Pointer<Float> pfVolumes) => ptr.ref.vtable
      .elementAt(7)
      .cast<
          Pointer<
              NativeFunction<
                  Int32 Function(
                      Pointer, Uint32 dwCount, Pointer<Float> pfVolumes)>>>()
      .value
      .asFunction<
          int Function(Pointer, int dwCount,
              Pointer<Float> pfVolumes)>()(ptr.ref.lpVtbl, dwCount, pfVolumes);
}
