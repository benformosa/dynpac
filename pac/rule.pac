// if on our WAN
if (isInNet(host, "10.0.0.0",  "255.0.0.0")) return "DIRECT";
if (isInNet(host, "127.0.0.0", "255.0.0.0")) return "DIRECT";
if (isPlainHostName(host)) return "DIRECT";

//if proxy is resolveable (i.e. on site)
if (isResolvable("proxy")) return proxy;

//Otherwise use direct
return "DIRECT";
}

