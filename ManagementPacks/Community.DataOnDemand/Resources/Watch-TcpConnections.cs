using System;
using System.Collections.Generic;
using System.Net;
using System.Net.NetworkInformation;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;

/// <summary>
/// Source file is run-time compiled as part of execution of agent task, so C# syntax level should be 2.0
/// </summary>
namespace SquaredUp
{
    public class SqupTcpStatsV01
    {
        public static TcpConnectionV01[] MonitorTcp(int nSeconds)
        {
            string computername = System.Environment.MachineName;

            IPHelperWrapper ipw = new IPHelperWrapper();
            Dictionary<string, TcpConnectionV01> connsByKey = new Dictionary<string, TcpConnectionV01>();

            DateTime startTime = DateTime.UtcNow;
            DateTime stopTime = startTime + TimeSpan.FromSeconds(nSeconds);

            bool first = true;
            while (DateTime.UtcNow < stopTime)
            {
                // Keep a note of the existing keys (so we can spot entries which are no longer coming back from GetAllTCPv4Connections
                List<string> connsNotSeen = new List<string>(connsByKey.Keys);   // (HashSet would be nicer here)

                // Get the current state of affairs with GetAllTCPv4Connections
                List<MIB_TCPROW_OWNER_PID> ipv4s = ipw.GetAllTCPv4Connections();

                // Process the results
                foreach (MIB_TCPROW_OWNER_PID ipv4 in ipv4s)
                {
                    // Ignore results with no PID
                    uint owningPid = ipv4.owningPid;
                    if (owningPid == 0) { continue; }

                    // Ignore listening state
                    TcpState state = (TcpState)ipv4.state;
                    if (state == TcpState.Listen) { continue; }

                    // Ignore loopback connections
                    IPEndPoint remote = new IPEndPoint(new IPAddress(ipv4.remoteAddr), ipv4.remotePort[0] << 8 | ipv4.remotePort[1]);
                    if (IPAddress.IsLoopback(remote.Address)) { continue; }
                    IPEndPoint local = new IPEndPoint(new IPAddress(ipv4.localAddr), ipv4.localPort[0] << 8 | ipv4.localPort[1]);

                    // ...so we are interested in this one
                    TcpConnectionV01 conn = new TcpConnectionV01(
                        computername,
                        local,
                        remote,
                        owningPid,
                        state,
                        first);

                    TcpConnectionV01 existingConn;
                    if (connsByKey.TryGetValue(conn.Key, out existingConn))
                    {
                        // We have seen this one before, update the state in the existing entry
                        if (existingConn.CurrentState == conn.CurrentState)
                        {
                            existingConn.StateSamples[existingConn.StateSamples.Count - 1].Count++;
                        }
                        else
                        {
                            existingConn.CurrentState = conn.CurrentState;
                            existingConn.StateSamples.Add(new TcpStateSampleV01(conn.CurrentState));
                        }

                        // Note that we have seen this one again
                        connsNotSeen.Remove(conn.Key);
                    }
                    else
                    {
                        // Create a new entry
                        conn.StateSamples.Add(new TcpStateSampleV01(conn.CurrentState));
                        conn.TimeFirstSeen = conn.StateSamples[0].TimeSampled;
                        conn.ProcessName = "Unknown";
                        conn.ProcessDescription = "Unknown";
                        connsByKey[conn.Key] = conn;
                    }
                }

                // Now go through all the ones we didn't see this time around and mark as gone
                foreach (string keyGone in connsNotSeen)
                {
                    TcpConnectionV01 conn = connsByKey[keyGone];
                    if (!conn.IsGone)
                    {
                        conn.IsGone = true;
                        conn.StateSamples.Add(new TcpStateSampleV01("|GONE|"));
                        conn.TimeFirstGone = conn.StateSamples[conn.StateSamples.Count - 1].TimeSampled;
                    }
                }

                // Wait one second
                Thread.Sleep(TimeSpan.FromSeconds(1));

                // New entries created after this point are not marked as being in the initial set.
                first = false;
            }

            List<TcpConnectionV01> results = new List<TcpConnectionV01>();

            foreach (TcpConnectionV01 conn in connsByKey.Values)
            {
                // Return
                if (conn.State == TcpState.Established.ToString() ||
                    conn.State == TcpState.SynSent.ToString())
                {
                    results.Add(conn);
                }
            }

            return results.ToArray();
        }

        #region pinvoke stuff
        // From: http://www.pinvoke.net/default.aspx/iphlpapi.GetExtendedTcpTable

        #region structs
        // http://msdn2.microsoft.com/en-us/library/aa366913.aspx
        [StructLayout(LayoutKind.Sequential)]
        private struct MIB_TCPROW_OWNER_PID
        {
            public uint state;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
            public byte[] localAddr;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
            public byte[] localPort;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
            public byte[] remoteAddr;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
            public byte[] remotePort;
            public uint owningPid;
        }

        // http://msdn2.microsoft.com/en-us/library/aa366921.aspx
        [StructLayout(LayoutKind.Sequential)]
        private struct MIB_TCPTABLE_OWNER_PID
        {
            public uint dwNumEntries;
            [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.Struct, SizeConst = 1)]
            public MIB_TCPROW_OWNER_PID[] table;
        }

        // http://msdn.microsoft.com/en-us/library/aa366896
        [StructLayout(LayoutKind.Sequential)]
        private struct MIB_TCP6ROW_OWNER_PID
        {
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
            public byte[] localAddr;
            public uint localScopeId;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
            public byte[] localPort;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
            public byte[] remoteAddr;
            public uint remoteScopeId;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
            public byte[] remotePort;
            public uint state;
            public uint owningPid;
        }

        // http://msdn.microsoft.com/en-us/library/windows/desktop/aa366905
        [StructLayout(LayoutKind.Sequential)]
        private struct MIB_TCP6TABLE_OWNER_PID
        {
            public uint dwNumEntries;
            [MarshalAs(UnmanagedType.ByValArray, ArraySubType = UnmanagedType.Struct, SizeConst = 1)]
            public MIB_TCP6ROW_OWNER_PID[] table;
        }
        #endregion

        #region enums
        // http://msdn2.microsoft.com/en-us/library/aa366386.aspx
        private enum TCP_TABLE_CLASS
        {
            TCP_TABLE_BASIC_LISTENER,
            TCP_TABLE_BASIC_CONNECTIONS,
            TCP_TABLE_BASIC_ALL,
            TCP_TABLE_OWNER_PID_LISTENER,
            TCP_TABLE_OWNER_PID_CONNECTIONS,
            TCP_TABLE_OWNER_PID_ALL,
            TCP_TABLE_OWNER_MODULE_LISTENER,
            TCP_TABLE_OWNER_MODULE_CONNECTIONS,
            TCP_TABLE_OWNER_MODULE_ALL
        }

        // http://msdn.microsoft.com/en-us/library/aa366896.aspx
        private enum MIB_TCP_STATE
        {
            MIB_TCP_STATE_CLOSED,
            MIB_TCP_STATE_LISTEN,
            MIB_TCP_STATE_SYN_SENT,
            MIB_TCP_STATE_SYN_RCVD,
            MIB_TCP_STATE_ESTAB,
            MIB_TCP_STATE_FIN_WAIT1,
            MIB_TCP_STATE_FIN_WAIT2,
            MIB_TCP_STATE_CLOSE_WAIT,
            MIB_TCP_STATE_CLOSING,
            MIB_TCP_STATE_LAST_ACK,
            MIB_TCP_STATE_TIME_WAIT,
            MIB_TCP_STATE_DELETE_TCB
        }
        #endregion

        #region APIs
        // http://msdn2.microsoft.com/en-us/library/aa366073.aspx
        private static class IPHelperAPI
        {
            [DllImport("iphlpapi.dll", SetLastError = true)]
            internal static extern uint GetExtendedTcpTable(
                IntPtr tcpTable,
                ref int tcpTableLength,
                bool sort,
                int ipVersion,
                TCP_TABLE_CLASS tcpTableType,
                int reserved);
        }
        #endregion

        #region wrapper class
        private class IPHelperWrapper : IDisposable
        {

            public const int AF_INET = 2;    // IP_v4 = System.Net.Sockets.AddressFamily.InterNetwork
            public const int AF_INET6 = 23;  // IP_v6 = System.Net.Sockets.AddressFamily.InterNetworkV6

            // Creates a new wrapper for the local machine
            public IPHelperWrapper() { }

            // Disposes of this wrapper
            public void Dispose() { GC.SuppressFinalize(this); }

            public List<MIB_TCPROW_OWNER_PID> GetAllTCPv4Connections()
            {
                return GetTCPConnections<MIB_TCPROW_OWNER_PID, MIB_TCPTABLE_OWNER_PID>(AF_INET);
            }

            public List<MIB_TCP6ROW_OWNER_PID> GetAllTCPv6Connections()
            {
                return GetTCPConnections<MIB_TCP6ROW_OWNER_PID, MIB_TCP6TABLE_OWNER_PID>(AF_INET6);
            }

            public List<IPR> GetTCPConnections<IPR, IPT>(int ipVersion)
            { //IPR = Row Type, IPT = Table Type

                IPR[] tableRows;
                int buffSize = 0;
                FieldInfo dwNumEntriesField = typeof(IPT).GetField("dwNumEntries");

                // how much memory do we need?
                uint ret = IPHelperAPI.GetExtendedTcpTable(IntPtr.Zero, ref buffSize, true, ipVersion, TCP_TABLE_CLASS.TCP_TABLE_OWNER_PID_ALL, 0);
                IntPtr tcpTablePtr = Marshal.AllocHGlobal(buffSize);

                try
                {
                    ret = IPHelperAPI.GetExtendedTcpTable(tcpTablePtr, ref buffSize, true, ipVersion, TCP_TABLE_CLASS.TCP_TABLE_OWNER_PID_ALL, 0);
                    if (ret != 0) return new List<IPR>();

                    // get the number of entries in the table
                    IPT table = (IPT)Marshal.PtrToStructure(tcpTablePtr, typeof(IPT));
                    int rowStructSize = Marshal.SizeOf(typeof(IPR));
                    uint numEntries = (uint)dwNumEntriesField.GetValue(table);

                    // buffer we will be returning
                    tableRows = new IPR[numEntries];

                    IntPtr rowPtr = (IntPtr)((long)tcpTablePtr + 4);
                    for (int i = 0; i < numEntries; i++)
                    {
                        IPR tcpRow = (IPR)Marshal.PtrToStructure(rowPtr, typeof(IPR));
                        tableRows[i] = tcpRow;
                        rowPtr = (IntPtr)((long)rowPtr + rowStructSize);   // next entry
                    }
                }
                finally
                {
                    // Free the Memory
                    Marshal.FreeHGlobal(tcpTablePtr);
                }
                return tableRows != null ? new List<IPR>(tableRows) : new List<IPR>();
            }

            // Occurs on destruction of the Wrapper
            ~IPHelperWrapper() { Dispose(); }

        } // wrapper class
        #endregion

        #endregion
    }

    #region inner classes
    public class TcpStateSampleV01
    {
        private int count = 1;
        private string state;
        private DateTime timeSampled;
        public int Count { get { return count; } set { count = value; } }
        public string State { get { return state; } set { state = value; } }
        public DateTime TimeSampled { get { return timeSampled; } set { timeSampled = value; } }

        public TcpStateSampleV01(TcpState state)
        {
            this.State = state.ToString();
            this.TimeSampled = DateTime.UtcNow;
        }

        public TcpStateSampleV01(string state)
        {
            this.State = state;
            this.TimeSampled = DateTime.UtcNow;
        }
    }

    public class TcpConnectionV01
    {
        private string computername;
        private uint pid;
        private string processName;
        private string processDescription;
        private IPEndPoint localEndpoint;
        private IPEndPoint remoteEndpoint;
        private TcpState currentState;
        private DateTime timeFirstSeen;
        private bool isGone;
        private DateTime timeFirstGone;
        private bool inInitialSet;

        public TcpConnectionV01(
            string computername,
            IPEndPoint localEndpoint,
            IPEndPoint remoteEndpoint,
            uint pid,
            TcpState currentState,
            bool inInitialSet)
        {
            this.computername = computername;
            this.localEndpoint = localEndpoint;
            this.remoteEndpoint = remoteEndpoint;
            this.pid = pid;
            this.currentState = currentState;
            this.inInitialSet = inInitialSet;
        }

        public string Computername { get { return computername; } set { computername = value; } }
        public uint PID { get { return pid; } set { pid = value; } }
        public string ProcessName { get { return processName; } set { processName = value; } }
        public string ProcessDescription { get { return processDescription; } set { processDescription = value; } }
        public string Protocol { get { return "TCP"; } }
        public IPEndPoint LocalEndpoint { get { return localEndpoint; } set { localEndpoint = value; } }
        public string LocalAddress { get { return LocalEndpoint.Address.ToString(); } }
        public string LocalPort { get { return LocalEndpoint.Port.ToString(); } }
        public IPEndPoint RemoteEndpoint { get { return remoteEndpoint; } set { remoteEndpoint = value; } }
        public string RemoteAddress { get { return RemoteEndpoint.Address.ToString(); } }
        public string RemotePort { get { return RemoteEndpoint.Port.ToString(); } }
        public TcpState CurrentState { get { return currentState; } set { currentState = value; } }
        public string RemoteAddressIP { get { return RemoteEndpoint.Address.ToString(); } }

        public DateTime TimeFirstSeen { get { return timeFirstSeen; } set { timeFirstSeen = value; } }
        public readonly List<TcpStateSampleV01> StateSamples = new List<TcpStateSampleV01>();
        public bool IsGone { get { return isGone; } set { isGone = value; } }
        public DateTime TimeFirstGone { get { return timeFirstGone; } set { timeFirstGone = value; } }
        public bool InInitialSet { get { return inInitialSet; } set { inInitialSet = value; } }
        public string Key { get { return LocalEndpoint.ToString() + "--" + RemoteEndpoint.ToString(); } }

        /// <summary>
        /// The effective state of the connection once sampling has completed
        /// </summary>
        public string State
        {
            get
            {
                foreach (TcpStateSampleV01 sample in StateSamples)
                {
                    if (sample.State == TcpState.Established.ToString())
                    {
                        // If we ever saw the link established, that's what we'll report
                        return TcpState.Established.ToString();
                    }
                }
                foreach (TcpStateSampleV01 sample in StateSamples)
                {
                    if (sample.State == TcpState.SynSent.ToString() && sample.Count > 3)
                    {
                        // If we never saw it established, but saw it waiting for a connection to complete
                        // for more than three samples, we'll report it as SynSent
                        return TcpState.SynSent.ToString();
                    }
                }
                return "NotInterested";
            }
        }
    }
    #endregion

}