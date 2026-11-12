import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/danusan_calculator.dart';

void main() {
  group('estimateDanusan', () {
    test('modal terpakai = total server, sisa = anggaran - total', () {
      final e = estimateDanusan(total: 440000, totalQty: 200, budget: 500000);
      expect(e.modalTerpakai, 440000);
      expect(e.sisaModal, 60000);
      expect(e.totalQty, 200);
    });

    test('tanpa anggaran: sisa modal tidak ada', () {
      final e = estimateDanusan(total: 440000, totalQty: 200);
      expect(e.sisaModal, isNull);
    });

    test('tanpa harga jual: pendapatan/laba/ROI tidak dihitung', () {
      final e = estimateDanusan(total: 440000, totalQty: 200, budget: 500000);
      expect(e.hasProfit, isFalse);
      expect(e.pendapatan, isNull);
      expect(e.laba, isNull);
      expect(e.roiPercent, isNull);
      // 0 atau negatif diperlakukan sama dengan kosong
      expect(estimateDanusan(total: 1, totalQty: 1, sellPrice: 0).hasProfit,
          isFalse);
    });

    test('pendapatan = harga jual x qty, laba, ROI persen', () {
      final e = estimateDanusan(
          total: 440000, totalQty: 200, budget: 500000, sellPrice: 4500);
      expect(e.pendapatan, 900000);
      expect(e.laba, 460000);
      // 460000 / 440000 = 104,545...% -> 104,5%
      expect(e.roiPercent, 104.5);
    });

    test('rugi: laba & ROI negatif', () {
      final e = estimateDanusan(total: 100000, totalQty: 10, sellPrice: 8000);
      expect(e.pendapatan, 80000);
      expect(e.laba, -20000);
      expect(e.roiPercent, -20.0);
    });

    test('pembulatan ROI satu desimal, setengah menjauhi nol', () {
      // 1 / 8 = 12,5% tepat
      expect(estimateDanusan(total: 8000, totalQty: 1, sellPrice: 9000)
          .roiPercent, 12.5);
      // 1 / 3 = 33,333...% -> 33,3%
      expect(estimateDanusan(total: 3000, totalQty: 1, sellPrice: 4000)
          .roiPercent, 33.3);
      // 2 / 3 = 66,666...% -> 66,7%
      expect(estimateDanusan(total: 3000, totalQty: 1, sellPrice: 5000)
          .roiPercent, 66.7);
      // 0,05% -> 0,1% ; -0,05% -> -0,1%
      expect(estimateDanusan(total: 200000, totalQty: 1, sellPrice: 200100)
          .roiPercent, 0.1);
      expect(estimateDanusan(total: 200000, totalQty: 1, sellPrice: 199900)
          .roiPercent, -0.1);
    });

    test('total 0: ROI tidak terdefinisi (null), tanpa bagi nol', () {
      final e = estimateDanusan(total: 0, totalQty: 0, budget: 50000, sellPrice: 5000);
      expect(e.modalTerpakai, 0);
      expect(e.sisaModal, 50000);
      expect(e.pendapatan, 0);
      expect(e.laba, 0);
      expect(e.roiPercent, isNull);
    });
  });

  group('formatRoi', () {
    test('tanda, koma desimal, tanpa ,0', () {
      expect(formatRoi(104.5), '+104,5%');
      expect(formatRoi(50.0), '+50%');
      expect(formatRoi(-20.0), '-20%');
      expect(formatRoi(-0.1), '-0,1%');
      expect(formatRoi(0.0), '0%');
      expect(formatRoi(null), '–');
    });
  });

  group('formatSignedRupiah', () {
    test('laba positif/negatif', () {
      expect(formatSignedRupiah(460000), '+Rp 460.000');
      expect(formatSignedRupiah(-20000), '-Rp 20.000');
      expect(formatSignedRupiah(0), 'Rp 0');
    });
  });
}
