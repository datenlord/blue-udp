import GetPut :: *;
import Connectable :: *;

import Ports :: *;
import EthernetTypes :: *;

import SemiFifo :: *;
import BusConversion :: *;

(* always_ready, always_enabled *)
interface RawUdpIpMetaDataBusSlave;
    (* prefix = "" *)
    method Action validData(
        (* port = "valid"    *) Bool valid,
        (* port = "ip_addr"  *) IpAddr ipAddr,
        (* port = "ip_dscp"  *) IpDscp ipDscp,
        (* port = "ip_ecn"   *) IpEcn ipEcn,
        (* port = "dst_port" *) UdpPort dstPort,
        (* port = "src_port" *) UdpPort srcPort,
        (* port = "data_len" *) UdpLength dataLen
    );

    (* result = "ready" *) method Bool ready;
endinterface

(* always_ready, always_enabled *)
interface RawUdpIpMetaDataBusMaster;
    (* result = "valid"    *) method Bool valid;
    (* result = "ip_addr"  *) method IpAddr ipAddr;
    (* result = "ip_dscp"  *) method IpDscp ipDscp;
    (* result = "ip_ecn"   *) method IpEcn ipEcn;
    (* result = "dst_port" *) method UdpPort dstPort;
    (* result = "src_port" *) method UdpPort srcPort;
    (* result = "data_len" *) method UdpLength dataLen;

    (* prefix = "" *)
    method Action ready((* port = "ready" *) Bool rdy);
endinterface

(* always_ready, always_enabled *)
interface RawMacMetaDataBusSlave;
    (* prefix = "" *)
    method Action validData(
        (* port = "valid"    *) Bool valid,
        (* port = "mac_addr" *) EthMacAddr macAddr,
        (* port = "eth_type" *) EthType ethType
    );
    
    (* result = "ready" *) method Bool ready;
endinterface


(* always_ready, always_enabled *)
interface RawMacMetaDataBusMaster;
    (* result = "valid"    *) method Bool valid;
    (* result = "mac_addr" *) method EthMacAddr macAddr;
    (* result = "eth_type" *) method EthType ethType;

    (* prefix = "" *)
    method Action ready((* port = "ready" *) Bool rdy);
endinterface


(* always_ready, always_enabled *)
interface RawDataStreamBusSlave;
    (* prefix = "" *)
    method Action validData(
        (* port = "tvalid" *) Bool valid,
        (* port = "tdata"  *) Data data,
        (* port = "tkeep"  *) ByteEn byteEn,
        (* port = "tfirst" *) Bool isFirst,
        (* port = "tlast"  *) Bool isLast
    );

    (* result = "tready" *) method Bool ready;
endinterface

(* always_ready, always_enabled *)
interface RawDataStreamBusMaster;
    (* result = "tvalid"*) method Bool valid;
    (* result = "tdata" *) method Data data;
    (* result = "tkeep" *) method ByteEn byteEn;
    (* result = "tfirst"*) method Bool isFirst;
    (* result = "tlast" *) method Bool isLast;

    (* prefix = "" *)
    method Action ready((* port = "tready" *) Bool rdy);
endinterface

(* always_ready, always_enabled *)
interface RawUdpConfigBusSlave;
    (* prefix = "" *)
    method Action validData(
        (* port = "valid"    *) Bool valid,
        (* port = "mac_addr" *) EthMacAddr macAddr,
        (* port = "ip_addr"  *) IpAddr ipAddr,
        (* port = "net_mask" *) IpNetMask netMask,
        (* port = "gate_way" *) IpGateWay gateWay
    );

    (* result = "ready" *) method Bool ready;
endinterface

(* always_ready, always_enabled *)
interface RawUdpConfigBusMaster;
    (* result = "valid"    *) method Bool       valid;
    (* result = "mac_addr" *) method EthMacAddr macAddr;
    (* result = "ip_addr"  *) method IpAddr     ipAddr;
    (* result = "net_mask" *) method IpNetMask  netMask;
    (* result = "gate_way" *) method IpGateWay  gateWay;

    (* prefix = "" *)
    method Action ready((* port = "ready" *) Bool rdy);
endinterface


module mkRawUdpIpMetaDataBusMaster#(UdpIpMetaDataFifoOut pipeIn)(RawUdpIpMetaDataBusMaster);
    RawBusMaster#(UdpIpMetaData) rawBus <- mkFifoOutToRawBusMaster(pipeIn);
    
    method Bool valid = rawBus.valid;
    method IpAddr ipAddr = rawBus.data.ipAddr;
    method IpDscp ipDscp = rawBus.data.ipDscp;
    method IpEcn  ipEcn  = rawBus.data.ipEcn;
    method UdpPort dstPort = rawBus.data.dstPort;
    method UdpPort srcPort = rawBus.data.srcPort;
    method UdpLength dataLen = rawBus.data.dataLen;

    method Action ready(Bool rdy);
        rawBus.ready(rdy);
    endmethod
endmodule


module mkRawUdpIpMetaDataBusSlave#(Put#(UdpIpMetaData) put)(RawUdpIpMetaDataBusSlave);
    RawBusSlave#(UdpIpMetaData) rawBus <- mkPutToRawBusSlave(put, CF);
    
    method Action validData(
        Bool valid,
        IpAddr ipAddr,
        IpDscp ipDscp,
        IpEcn  ipEcn,
        UdpPort dstPort,
        UdpPort srcPort,
        UdpLength dataLen
    );
        UdpIpMetaData metaData = UdpIpMetaData {
            ipAddr: ipAddr,
            ipDscp: ipDscp,
            ipEcn: ipEcn,
            dstPort: dstPort,
            srcPort: srcPort,
            dataLen: dataLen
        };
        rawBus.validData(valid, metaData);
    endmethod
    method Bool ready = rawBus.ready;
endmodule

module mkRawMacMetaDataBusMaster#(MacMetaDataFifoOut pipe)(RawMacMetaDataBusMaster);
    RawBusMaster#(MacMetaData) rawBus <- mkFifoOutToRawBusMaster(pipe);
    
    method Bool valid = rawBus.valid;
    method EthMacAddr macAddr = rawBus.data.macAddr;
    method EthType ethType = rawBus.data.ethType;

    method Action ready(Bool rdy);
        rawBus.ready(rdy);
    endmethod
endmodule

module mkRawMacMetaDataBusSlave#(Put#(MacMetaData) put)(RawMacMetaDataBusSlave);
    RawBusSlave#(MacMetaData) rawBus <- mkPutToRawBusSlave(put, CF);
    method Action validData(
        Bool valid,
        EthMacAddr macAddr,
        EthType ethType
    );
        MacMetaData metaData = MacMetaData {
            macAddr: macAddr,
            ethType: ethType
        };
        rawBus.validData(valid, metaData);
    endmethod
    method Bool ready = rawBus.ready;
endmodule


module mkRawDataStreamBusMaster#(DataStreamFifoOut pipe)(RawDataStreamBusMaster);
    RawBusMaster#(DataStream) rawBus <- mkFifoOutToRawBusMaster(pipe);
    
    method Bool valid = rawBus.valid;
    method ByteEn byteEn = rawBus.data.byteEn;
    method Data data = rawBus.data.data;
    method Bool isFirst = rawBus.data.isFirst;
    method Bool isLast = rawBus.data.isLast;

    method Action ready(Bool rdy);
        rawBus.ready(rdy);
    endmethod
endmodule

module mkRawDataStreamBusSlave#(Put#(DataStream) putIn)(RawDataStreamBusSlave);
    RawBusSlave#(DataStream) rawBus <- mkPutToRawBusSlave(putIn, CF);

    method Action validData(
        Bool valid,
        Data   data,
        ByteEn byteEn,
        Bool   isFirst,
        Bool   isLast
    );
        DataStream dataStream = DataStream {
            data  : data,
            byteEn: byteEn,
            isFirst: isFirst,
            isLast: isLast
        };
        rawBus.validData(valid, dataStream);
    endmethod
    method Bool ready = rawBus.ready;
endmodule


module mkRawUdpConfigBusSlave#(Put#(UdpConfig) put)(RawUdpConfigBusSlave);
    RawBusSlave#(UdpConfig) rawBus <- mkPutToRawBusSlave(put, CF);

    method Action validData(
        Bool valid,
        EthMacAddr macAddr,
        IpAddr ipAddr,
        IpNetMask netMask,
        IpGateWay gateWay
    );
        UdpConfig udpConfig = UdpConfig {
            macAddr: macAddr,
            ipAddr : ipAddr,
            netMask: netMask,
            gateWay: gateWay
        };
        rawBus.validData(valid, udpConfig);
    endmethod
    method Bool ready = rawBus.ready;
endmodule

module mkRawUdpConfigBusMaster#(FifoOut#(UdpConfig) pipe)(RawUdpConfigBusMaster);
    RawBusMaster#(UdpConfig) rawBus <- mkFifoOutToRawBusMaster(pipe);

    method valid = rawBus.valid;
    method EthMacAddr macAddr = rawBus.data.macAddr;
    method IpAddr ipAddr = rawBus.data.ipAddr;
    method IpNetMask netMask = rawBus.data.netMask;
    method IpGateWay gateWay = rawBus.data.gateWay;
    
    method Action ready(Bool rdy);
        rawBus.ready(rdy);
    endmethod
endmodule

