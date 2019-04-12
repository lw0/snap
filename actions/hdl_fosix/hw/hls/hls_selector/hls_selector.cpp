#include <hls_stream.h>
#include <ap_int.h>

typedef ap_uint<512> Tdata;
typedef ap_uint<64> Tdata_strb;
typedef ap_uint<1> Tbool;
typedef ap_uint<16> Tmask;
typedef ap_uint<2> Tmask_strb;
typedef ap_int<32> Tvalue;
typedef ap_uint<32> Tmode;

typedef struct {
  Tdata tdata;
  Tdata_strb tkeep;
  Tbool tlast;
} Tdata_item;
typedef hls::stream<Tdata_item> Tdata_stream;

typedef struct {
  Tmask tdata;
  Tmask_strb tkeep;
  Tbool tlast;
} Tmask_item;
typedef hls::stream<Tmask_item> Tmask_stream;

Tdata_strb expand_mask(Tmask m) {
  Tdata_strb k = 0;
  for (int i = 0; i < 16; ++i) {
#pragma HLS unroll
    if (m(i,i) == 0) {
      k(3*i+3, 3*i) = 0x0;
    } else {
      k(3*i+3, 3*i) = 0xf;
    }
  }
  return k;
}

void hls_selector(Tdata_stream & input, Tmask_stream & mask, Tdata_stream & output) {
#pragma HLS interface axis port=input name=stmIn
#pragma HLS interface axis port=mask name=stmMsk
#pragma HLS interface axis port=output name=stmOut
  Tdata_item in, out;
  Tmask_item msk;
  do {
#pragma HLS pipeline
    in = input.read();
    msk = mask.read();

    if(msk.tdata != 0) {
      out.tdata = in.tdata;
      out.tkeep = expand_mask(msk.tdata);
      out.tlast = in.tlast;
      output.write(out);
    }
  } while(!in.tlast);
}
