#include <hls_stream.h>
#include <ap_int.h>

typedef ap_uint<1> Tbool;
typedef ap_uint<4> Tidx;
typedef ap_uint<16> Tmask;
typedef ap_uint<2> Tmask_strb;
typedef ap_uint<32> Treg;

typedef struct {
  Tmask tdata;
  Tmask_strb tkeep;
  Tbool tlast;
} Tmask_item;
typedef hls::stream<Tmask_item> Tmask_stream;

Tmask combine(Tmask m0, Tmask m1, Tmask m2, Tmask m3, Treg function) {
  Tmask result = 0;
  for (int i = 0; i < 16; ++i) {
#pragma HLS unroll
    Tidx idx = (m3(i,i), m2(i,i), m1(i,i), m0(i,i));
    result(i,i) = function(idx,idx);
  }
  return result;
}

void hls_logic(Tmask_stream & in0, Tmask_stream & in1, Tmask_stream & in2, Tmask_stream & in3, Tmask_stream & out, Treg function) {
#pragma HLS interface axis port=in0 name=stmIn0
#pragma HLS interface axis port=in1 name=stmIn1
#pragma HLS interface axis port=in2 name=stmIn2
#pragma HLS interface axis port=in3 name=stmIn3
#pragma HLS interface axis port=out name=stmOut
#pragma HLS interface ap_stable port=function name=regFunc
  Tmask_item m0, m1, m2, m3, mc;
  do {
#pragma HLS pipeline
    m0 = in0.read();
    m1 = in1.read();
    m2 = in2.read();
    m3 = in3.read();

    mc.tdata = combine(m0.tdata, m1.tdata, m2.tdata, m3.tdata, function);
    mc.tkeep = -1;
    mc.tlast = m0.tlast;
    out.write(mc);
  } while(!m0.tlast);
}
