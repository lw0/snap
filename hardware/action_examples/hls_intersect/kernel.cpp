/*
 * Copyright 2017, International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#include <string.h>
#include "ap_int.h"
#include "action_intersect.H"

//--------------------------------------------------------------------------------------------
// v1.0 : 03/24/2017 : creation 
// v1.1 : 04/05/2017 : multiple changes to fit new config reg mapping 
// v1.2 : 04/13/2017 : Add Hash/Sort and more steps 
//--------------------------------------------------------------------------------------------

static snapu32_t read_bulk_ddr ( snap_membus_t *d_ddrmem,
                            snapu64_t      byte_address,
                            snapu32_t      byte_to_transfer,
                            snap_membus_t *buffer)
{

    snapu32_t xfer_size;
    xfer_size = MIN(byte_to_transfer, (snapu32_t) MAX_NB_OF_BYTES_READ);
    memcpy(buffer, (snap_membus_t *) (d_ddrmem + (byte_address >> ADDR_RIGHT_SHIFT)), xfer_size);
    return xfer_size;
}

static snapu32_t write_bulk_ddr (snap_membus_t *d_ddrmem, 
                            snapu64_t      byte_address, 
                            snapu32_t      byte_to_transfer,
                            snap_membus_t *buffer)
{
    snapu32_t xfer_size;
    xfer_size = MIN(byte_to_transfer, (snapu32_t)  MAX_NB_OF_BYTES_READ);
    memcpy((snap_membus_t *)(d_ddrmem + (byte_address >> ADDR_RIGHT_SHIFT)), buffer, xfer_size);
    return xfer_size;
}

static void memcopy_table(snap_membus_t  *din_gmem, 
                    snap_membus_t  *dout_gmem, 
                    snap_membus_t  *d_ddrmem,
                    snapu64_t       source_address , 
                    snapu64_t       target_address, 
                    snapu32_t       total_bytes_to_transfer, 
                    snap_bool_t     direction)
{
    //direction == 0: Copy from Host to DDR
    //direction == 1: Copy from DDR to Host
    
    //source_address and target_address are byte addresses.
    snapu32_t xfer_size;
    snapu64_t address_xfer_offset;
    int left_bytes = total_bytes_to_transfer;
    snap_membus_t   buf_gmem[MAX_NB_OF_BYTES_READ/BPERDW];
    address_xfer_offset = 0;

L_COPY: while(left_bytes > 0)
    {
        
        xfer_size = MIN(left_bytes, (int) MAX_NB_OF_BYTES_READ);
        if(direction == 0)
        {
            memcpy(buf_gmem,   (snap_membus_t *) (din_gmem + ((source_address + address_xfer_offset) >> ADDR_RIGHT_SHIFT)), xfer_size);
            memcpy((snap_membus_t *)(d_ddrmem + ((target_address + address_xfer_offset) >> ADDR_RIGHT_SHIFT)), buf_gmem, xfer_size);
        }
        else
        {
            memcpy(buf_gmem,   (snap_membus_t *) (d_ddrmem + ((source_address + address_xfer_offset) >> ADDR_RIGHT_SHIFT)), xfer_size);
            memcpy((snap_membus_t *)(dout_gmem + ((target_address + address_xfer_offset) >> ADDR_RIGHT_SHIFT)), buf_gmem, xfer_size);
        }

        left_bytes -= xfer_size;
        address_xfer_offset += (snapu64_t)xfer_size;
    } // end of L_COPY

}

static short compare(value_t a, value_t b)
{

//    ap_uint<256> halfa;
//    ap_uint<256> halfb;
//
//    short kkk = 0;
//    for(kkk = 0; kkk < 2; kkk++)
//    {
//        halfa = a(255 + (kkk<<8), kkk<<8);
//        halfb = b(255 + (kkk<<8), kkk<<8);
//        if(halfa > halfb)
//            return 1;
//        else
//            return -1;
//    }
//    return 0;


    snapu16_t kkk =0;
    snapu8_t byte1, byte2;
#pragma HLS UNROLL
    for (kkk = 0; kkk < sizeof(value_t); kkk++)
    {
        byte1 = a((kkk<<3 )+7, kkk<<3);
        byte2 = b((kkk<<3 )+7, kkk<<3);

        if (byte1 > byte2)
            return 1;
        else if (byte1 < byte2)
            return -1;
    }
    return 0;
}


static uint32_t ht_hash(value_t key)
{
    
    snapu16_t bit = 0;
    snapu16_t k = 0;
    snapu16_t high_bound;
    //do it in parallel
    
    ap_uint<HT_ENTRY_NUM_EXP> hash_val = 0;
    while (bit < ENTRY_BYTES*8 )
    {
        high_bound = MIN((snapu16_t)( ENTRY_BYTES * 8 -1),(snapu16_t)( HT_ENTRY_NUM_EXP*k + HT_ENTRY_NUM_EXP - 1));
        hash_val += key(high_bound, HT_ENTRY_NUM_EXP*k);
        bit += HT_ENTRY_NUM_EXP;
        k ++;
    }

    //return hashval %HT_ENTRY_NUM;  //This step is not needed as we limit hashval to 24bits.  
    return hash_val ; 
}


static short make_hashtable(snap_membus_t  *d_ddrmem,
                     action_reg *Action_Register)
{
    //Something to be cautious: 
    // int type can represent -2G~+2G
    // Input table size is designed to be <=1GB
    snapu32_t index;

    short ijk;
    snapu32_t read_bytes;
    snapu64_t addr = Action_Register->Data.ddr_table1.address; 
    int left_bytes = Action_Register->Data.ddr_table1.size;
    snapu32_t offset = 0;
    
    value_t keybuf[MAX_NB_OF_BYTES_READ/BPERDW];
    value_t hash_entry;

    ap_uint<5> count;
    snap_bool_t used = 0;


    //Hash Table arrangement: 
    // Starting from HASH_TABLE_ADDR
    // Only stores the address of input 
    // Still 64bytes: 
    // Byte0-3: Count 
    // Byte4-7: offset0  (offset to ddr_table1.address)
    // Byte8-11: offset1 
    // ....
    // Byte60-63: offset14 

     while (left_bytes > 0)
    {
        read_bytes = read_bulk_ddr (d_ddrmem, addr,  left_bytes, keybuf);
        
        for (ijk = 0; ijk < read_bytes/BPERDW; ijk++)
        {
            index = ht_hash(keybuf[ijk]);

            used = hash_used[index>>WIDTH_EXP](index(WIDTH_EXP-1,0), index(WIDTH_EXP-1,0));
            hash_entry = 0;
            if(used == 0)
            {
                hash_used[index>>WIDTH_EXP](index(WIDTH_EXP-1,0), index(WIDTH_EXP-1,0)) = 1;
                hash_entry(31,0) = 1;
                hash_entry(63,32) = offset;
                write_bulk_ddr(d_ddrmem, HASH_TABLE_ADDR + index * BPERDW, BPERDW, &hash_entry);
            }
            else
            {
                read_bulk_ddr(d_ddrmem, HASH_TABLE_ADDR + index * BPERDW, BPERDW, &hash_entry);
                count = hash_entry(31,0);

                if (count >= 15)
                    return -1; //Hash Table is full. 
                else
                {
                    hash_entry(31,0) = count + 1;
                    hash_entry((count+1)*32+31, (count+1)*32) = offset;
                    write_bulk_ddr(d_ddrmem, HASH_TABLE_ADDR + index * BPERDW, BPERDW, &hash_entry);
                }
            }
            
            offset += BPERDW;
            

        }
        left_bytes -= MAX_NB_OF_BYTES_READ;
        addr       += MAX_NB_OF_BYTES_READ;
    }
    return 0;
}

static void check_table2(snap_membus_t  *d_ddrmem,
                  action_reg      *Action_Register)
{
    snapu32_t index;

    short iii;
    short j;
    snapu32_t read_bytes;
    snapu64_t addr = Action_Register->Data.ddr_table2.address; 
    int left_bytes = Action_Register->Data.ddr_table2.size;
    snapu32_t offset = 0;
    
    value_t keybuf[MAX_NB_OF_BYTES_READ/BPERDW];
    value_t hash_entry;
    value_t node_a;

    snapu32_t count;
    snapu32_t res_size = 0;
    snapu64_t write_addr = Action_Register->Data.res_table.address;
    
    snap_bool_t used = 0;

    while (left_bytes > 0)
    {
        read_bytes = read_bulk_ddr (d_ddrmem, addr,  left_bytes, keybuf);
        
        for (iii = 0; iii < read_bytes/BPERDW; iii++)
        {
            //Current element in Table2 is keybuf[i]
            index = ht_hash(keybuf[iii]);
            
            used =  hash_used[index>>WIDTH_EXP](index(WIDTH_EXP-1,0), index(WIDTH_EXP-1,0));
            if(used == 1)
            {
                read_bulk_ddr(d_ddrmem, HASH_TABLE_ADDR + index * BPERDW, BPERDW, &hash_entry);
                count = hash_entry(31,0); //How many elements are in the same hash table index
                                             //If count == 0, this element in Table2 doesn't exist in Table1.
                for (j = 0; j < count; j++)
                {
                    //Go to read Table1
                    offset = hash_entry(32*(j+1)+31, 32*(j+1));

                    read_bulk_ddr(d_ddrmem, Action_Register->Data.ddr_table1.address + offset, BPERDW, &node_a);

                    if (compare(node_a, keybuf[iii] ) == 0)
                    {
                            //match!
                        write_bulk_ddr(d_ddrmem, write_addr, BPERDW, &node_a);
                        res_size += BPERDW; 
                        write_addr += BPERDW;
                        break;
                    }
                }
            }
        }
        left_bytes -= MAX_NB_OF_BYTES_READ;
        addr       += MAX_NB_OF_BYTES_READ;
    }
    Action_Register->Data.res_table.size = res_size;
    Action_Register->Data.method = HASH_METHOD + 0x1000;
}

//--------------------------------------------------------------------------------------------
//--- MAIN PROGRAM ---------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------
void action_wrapper(snap_membus_t  *din_gmem,
                     snap_membus_t  *dout_gmem,
	                 snap_membus_t  *d_ddrmem,
                     action_reg            *Action_Register,
                     action_RO_config_reg  *Action_Config)
{

// Host Memory AXI Interface
#pragma HLS INTERFACE m_axi port=din_gmem bundle=host_mem offset=slave depth=512
#pragma HLS INTERFACE m_axi port=dout_gmem bundle=host_mem offset=slave depth=512
#pragma HLS INTERFACE s_axilite port=din_gmem bundle=ctrl_reg 		offset=0x030
#pragma HLS INTERFACE s_axilite port=dout_gmem bundle=ctrl_reg 		offset=0x040

//DDR memory Interface
#pragma HLS INTERFACE m_axi port=d_ddrmem bundle=card_mem0 offset=slave depth=512
#pragma HLS INTERFACE s_axilite port=d_ddrmem bundle=ctrl_reg 		offset=0x050

// Host Memory AXI Lite Master Interface
#pragma HLS DATA_PACK variable=Action_Config
#pragma HLS INTERFACE s_axilite port=Action_Config bundle=ctrl_reg	offset=0x010 
#pragma HLS DATA_PACK variable=Action_Register
#pragma HLS INTERFACE s_axilite port=Action_Register bundle=ctrl_reg	offset=0x100 
#pragma HLS INTERFACE s_axilite port=return bundle=ctrl_reg

// Hardcoded numbers
    Action_Config->action_type   = (snapu32_t) INTERSECT_ACTION_TYPE;
    Action_Config->release_level = (snapu32_t) RELEASE_LEVEL;

    short rc = 0;

    if(Action_Register->Data.step == 1)
    {
        //Copy from Host to DDR
        // Table1
        memcopy_table(din_gmem, dout_gmem, d_ddrmem,
            Action_Register->Data.src_table1.address, Action_Register->Data.ddr_table1.address, 
            Action_Register->Data.src_table1.size, 0);
        // Table2
        memcopy_table(din_gmem, dout_gmem, d_ddrmem,
            Action_Register->Data.src_table2.address, Action_Register->Data.ddr_table2.address, 
            Action_Register->Data.src_table2.size, 0);

        if(Action_Register->Data.method == HASH_METHOD)
        {
            snapu32_t i;
            for(i = 0; i < (HT_ENTRY_NUM >> WIDTH_EXP); i++)
                hash_used[i]=0;
        }
            

    }
    else if(Action_Register->Data.step == 2)
    {
        //Copy from DDR to Host
        // Table1
        memcopy_table(din_gmem, dout_gmem, d_ddrmem,
            Action_Register->Data.ddr_table1.address, Action_Register->Data.src_table1.address, 
            Action_Register->Data.ddr_table1.size, 1);
        // Table2
        memcopy_table(din_gmem, dout_gmem, d_ddrmem,
            Action_Register->Data.ddr_table2.address, Action_Register->Data.src_table2.address, 
            Action_Register->Data.ddr_table2.size, 1);
    }
    else if(Action_Register->Data.step == 3)
    {
        if(Action_Register->Data.method == HASH_METHOD) 
        {
            //Make hash table
            rc = make_hashtable(d_ddrmem, Action_Register);
            if(rc != 0)
            {
                Action_Register->Control.Retc = RET_CODE_FAILURE;
                return;
            }
            check_table2(d_ddrmem, Action_Register);
        }
       // else if (Action_Register->Data.method == SORT_METHOD)
       // {
       //     merge_sort(d_ddrmem, Action_Register);
       //     intersection(d_ddrmem, Action_Register);
       // }
        

    }
    else if (Action_Register->Data.step == 5)
    {
        //Copy Result from DDR to Host. 
        memcopy_table(din_gmem, dout_gmem, d_ddrmem, 
        Action_Register->Data.ddr_table1.address, Action_Register->Data.res_table.address, 
        Action_Register->Data.res_table.size, 1); 
    }
        
    Action_Register->Control.Retc = RET_CODE_OK;
    return;
}

