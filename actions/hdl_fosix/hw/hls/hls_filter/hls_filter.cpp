#include <hls_stream.h>
#include <ap_int.h>

typedef ap_uint<512> Tdata;
typedef ap_uint<1> Tbool;
typedef ap_uint<16> Tmask;
typedef ap_int<32> Tvalue;
typedef ap_uint<32> Tmode;

#define LOP(M) (M(3,2))
#define ROP(M) (M(1,0))
#define OP_NONE (0x0)
#define OP_LESS (0x1)
#define OP_EQUL (0x2)
#define OP_LSEQ (0x3)

typedef struct {
	Tdata tdata;
	Tbool tlast;
} Tdata_item;
typedef hls::stream<Tdata_item> Tdata_stream;

typedef struct {
	Tmask tdata;
	Tbool tlast;
} Tmask_item;
typedef hls::stream<Tmask_item> Tmask_stream;

Tbool match(Tvalue val, Tvalue ref, Tvalue lconst, Tvalue rconst, Tmode mode) {
	Tbool lcmp = 0, rcmp = 0;
	Tvalue lref = ref + lconst;
	Tvalue rref = ref + rconst;
	switch(LOP(mode)) {
	case OP_NONE:
		lcmp = 1;
		break;
	case OP_LESS:
		lcmp = (lref < val);
		break;
	case OP_EQUL:
		lcmp = (lref == val);
		break;
	case OP_LSEQ:
		lcmp = (lref <= val);
		break;
	}
	switch(ROP(mode)) {
	case OP_NONE:
		rcmp = 1;
		break;
	case OP_LESS:
		rcmp = (val < rref);
		break;
	case OP_EQUL:
		rcmp = (val == rref);
		break;
	case OP_LSEQ:
		rcmp = (val <= rref);
		break;
	}
	return lcmp && rcmp;
}

Tmask match_bundle(Tdata values, Tdata references, Tvalue lconst, Tvalue rconst, Tmode mode) {
	Tmask res = 0;
	for (int i = 0; i < 16; ++i) {
#pragma HLS unroll
		res(i,i) = match(values(32*i+31, 32*i), references(32*i+31, 32*i), lconst, rconst, mode);
	}
	return res;
}

void hls_filter(Tdata_stream & input, Tdata_stream & reference, Tmask_stream & output, Tvalue lconst, Tvalue rconst, Tmode mode) {
#pragma HLS interface axis port=input name=stmIn
#pragma HLS interface axis port=reference name=stmRef
#pragma HLS interface axis port=output name=stmOut
#pragma HLS interface ap_stable port=lconst name=regLConst
#pragma HLS interface ap_stable port=rconst name=regRConst
#pragma HLS interface ap_stable port=mode name=regMode
	Tdata_item in, ref;
	Tmask_item msk;
	do {
#pragma HLS pipeline
		in = input.read();
		ref = reference.read();

		msk.tdata = match_bundle(in.tdata, ref.tdata, lconst, rconst, mode);
		msk.tlast = in.tlast;
		output.write(msk);
	} while(!in.tlast);
}
