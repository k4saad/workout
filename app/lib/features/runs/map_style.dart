import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Brightness of the map, 0..1: how much of the tile's lightness survives.
const _k = 0.62;

/// Where the dark floor sits: tile lightness below this goes black.
const _floor = 0.74;

/// OSM's standard tiles, made quiet enough to run on.
///
/// The standard style is a full-colour street map — every building, shop
/// icon and park — and inverting it (flutter_map's dark mode) keeps all of
/// that, reversed. Instead each tile goes to greyscale and then to a narrow
/// dark band: the pale land becomes near-black, the white roads a soft grey
/// line just above it, water and parks sink below, and the text all but
/// disappears. The crimson trail is then the brightest thing on the screen,
/// which is the point of a run map.
///
/// Same tiles, same host (`tile.openstreetmap.org`): a cleaner vector style
/// would mean a second map server, which is Saad's decision, not a default.
const quietMapFilter = ColorFilter.matrix(<double>[
  _k * 0.2126, _k * 0.7152, _k * 0.0722, 0, -_floor * _k * 255 - 1, //
  _k * 0.2126, _k * 0.7152, _k * 0.0722, 0, -_floor * _k * 255, //
  _k * 0.2126, _k * 0.7152, _k * 0.0722, 0, -_floor * _k * 255 + 3, //
  0, 0, 0, 1, 0, //
]);

/// The tile builder that applies [quietMapFilter].
Widget quietTileBuilder(BuildContext context, Widget tile, TileImage image) =>
    ColorFiltered(colorFilter: quietMapFilter, child: tile);
