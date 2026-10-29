import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/util/search_fold.dart';

void main() {
  test('maps accented Latin letters', () {
    expect(foldSearch('àáâãäå'), 'aaaaaa');
    expect(foldSearch('ç'), 'c');
    expect(foldSearch('èéêë'), 'eeee');
    expect(foldSearch('ìíîï'), 'iiii');
    expect(foldSearch('ñ'), 'n');
    expect(foldSearch('òóôõö'), 'ooooo');
    expect(foldSearch('ùúûü'), 'uuuu');
    expect(foldSearch('ýÿ'), 'yy');
    expect(foldSearch('œ'), 'oe');
    expect(foldSearch('æ'), 'ae');
    expect(foldSearch('ß'), 'ss');
  });

  test('lowercases and folds uppercase forms', () {
    expect(foldSearch('ÉPICES'), 'epices');
    expect(foldSearch('Œuf'), 'oeuf');
    expect(foldSearch('Bouaké'), 'bouake');
    expect(foldSearch('Crème fraîche'), 'creme fraiche');
    expect(foldSearch('ÀÇÑ'), 'acn');
  });

  test('leaves other characters unchanged', () {
    expect(foldSearch('100% pur_2 : x'), '100% pur_2 : x');
    expect(foldSearch(''), '');
    expect(foldSearch('日本'), '日本');
  });
}
