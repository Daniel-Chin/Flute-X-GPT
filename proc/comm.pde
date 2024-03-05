import java.util.Arrays;
import java.util.concurrent.*;
import java.net.*;
import java.nio.*;
import java.io.Closeable;
import java.util.HashMap;

Comm comm;

final int DEVICE_FLUTE = 0;
final int DEVICE_GLOVE_L = 1;
final int DEVICE_GLOVE_R = 2;
final int N_DEVICES = 3;
final String[] DEVICE_NAMES = {
    "flute", 
    "glove_L", 
    "glove_R", 
};

enum HandshakeStage {
    OPENING, FINISHED, 
}
enum RecvOrSend {
    RECV, SEND, 
}
enum UDPorTCP {
    UDP, TCP, 
}

enum CommWhichQueue {
  // according to "communication_protocol.txt"
  SYNTH((int) 'M'), 
  AUTO_POF((int) 'A'), 
  ;

  private static HashMap<Integer, CommWhichQueue> hashMap;
  private final int id;

  static {
    hashMap = new HashMap<Integer, CommWhichQueue>();
    for (CommWhichQueue e : CommWhichQueue.values()) {
      hashMap.put(Integer.valueOf(e.getID()), e);
    }
  }

  private CommWhichQueue(int id) {
    this.id = id;
  }

  public int getID() {
    return id;
  }

  public static CommWhichQueue fromID(int id) {
    return hashMap.get(Integer.valueOf(id));
  }
}

class Comm {
    final static int UDP_PORT = 2352;
    final static int HOST_TCP_PORT = 2353;

    final static int TIMEOUT = 100;
    final static int BUF_SIZE = 1024;
    final static boolean HAS_PEDAL = false;  // if no pedal, there is atmosphere noise

    private DatagramSocket udpSock;
    private ServerSocket   tcpServerSock;
    private boolean should_exit = false;

    private HandshakeStage[] handshake_stage;
    public boolean redirect_bang = false;
    public int[] rtt = new int[N_DEVICES];

    private SocketAddress[] udp_remote_addrs;
    private Socket[] tcp_socks;
    private Logger logger;
    private TCPAccepter tcpAccepter;
    private UDPReceiver   udpReceiver;
    private TCPReceiver[] tcpReceivers;

    static final private int PACKET_LEN_T = 13;
    private byte[] packetToSend_T = new byte[PACKET_LEN_T];
    static final private int PACKET_LEN_B = 1;
    private byte[] packetToSend_B = new byte[PACKET_LEN_W];
    static final private int PACKET_LEN_S = 5;
    private byte[] packetToSend_S = new byte[PACKET_LEN_S];
    static final private int PACKET_LEN_D = 6;
    private byte[] packetToSend_D = new byte[PACKET_LEN_D];
    static final private int PACKET_LEN_C = 2;
    private byte[] packetToSend_C = new byte[PACKET_LEN_C];
    static final private int PACKET_LEN_P = 3;
    private byte[] packetToSend_P = new byte[PACKET_LEN_P];
    static final private int PACKET_LEN_M = 2;
    private byte[] packetToSend_M = new byte[PACKET_LEN_M];
    static final private int PACKET_LEN_A = 2;
    private byte[] packetToSend_A = new byte[PACKET_LEN_A];
    static final private int PACKET_LEN_O = 3;
    private byte[] packetToSend_O = new byte[PACKET_LEN_O];
    static final private int PACKET_LEN_N = 12;
    private byte[] packetToSend_N = new byte[PACKET_LEN_N];
    static final private int PACKET_LEN_L = 2;
    private byte[] packetToSend_L = new byte[PACKET_LEN_L];
    static final private int PACKET_LEN_W = 1;
    private byte[] packetToSend_W = new byte[PACKET_LEN_W];
    static final private int PACKET_LEN_r = 1;
    private byte[] packetToSend_r = new byte[PACKET_LEN_r];

    private ByteBuffer packet_T_intWriter;
    private ByteBuffer packet_N_intWriter;

    private class CloseNowException extends SilentException { }
    private void breathe() {
        if (should_exit)
            throw new CloseNowException();
    }
    
    private class Logger extends CaughtThread {
        private class Entry {
            public int len;
            public byte[] buf;
            public RecvOrSend recvOrSend;
            public UDPorTCP udpOrTcp;
            public int device_i;
        }

        private LinkedBlockingQueue<Entry> queue;
        private PrintWriter printWriter;

        public Logger() {
            super("Comm.Logger");
            queue = new LinkedBlockingQueue<Entry>();
            printWriter = createWriter("./comm.log");
        }

        public void add(
            int len, byte[] buf, 
            RecvOrSend recvOrSend, UDPorTCP udpOrTcp, 
            int device_i
        ) {
            Entry entry = new Entry();
            entry.len = len;
            entry.buf = buf;
            entry.recvOrSend = recvOrSend;
            entry.udpOrTcp = udpOrTcp;
            entry.device_i = device_i;
            queue.add(entry);
        }

        protected void caughtRun() {
            while (true) {
                breathe();
                Entry entry;
                try {
                    entry = queue.poll(TIMEOUT, TimeUnit.MILLISECONDS);
                } catch (InterruptedException e) {
                    fatalError(e);
                    return;
                }
                if (entry == null)
                    continue;
                logOne(entry);
            }
        }

        private void logOne(Entry entry) {
            printWriter.print(str(millis()));
            printWriter.print(" ");
            switch (entry.recvOrSend) {
                case RECV:
                    printWriter.print("??????? -> proc ");
                    break;
                case SEND:
                    printWriter.print("proc -> ");
                    printWriter.print(String.format(
                        "%1$7s", DEVICE_NAMES[entry.device_i]
                    ));
                    printWriter.print(" ");
                    break;
            }
            switch (entry.udpOrTcp) {
                case UDP:
                    printWriter.print("[UDP] ");
                    break;
                case TCP:
                    printWriter.print("[TCP] ");
                    break;
            }
            printWriter.println(new String(
                entry.buf, 0, entry.len, 
                StandardCharsets.US_ASCII
            ));
        }

        public void close() {
            printWriter.flush();
            printWriter.close();
        }
    }

    private byte readOne(InputStream stream) {
        int byte_;
        while (true) {
            breathe();
            try {
                byte_ = stream.read();
                if (byte_ == -1)
                    throw new IOException();
                return (byte) byte_;
            } catch (SocketTimeoutException e) {
                continue;
            } catch (IOException e) {
                breathe();
                fatalError(e);
            }
        }
    }

    private class TCPAccepter extends CaughtThread {
        public TCPAccepter() {
            super("TCPAccepter");
        }

        protected void caughtRun() {
            for (int i = 0; i < N_DEVICES; i ++) {
                Socket sock;
                while (true) {
                    breathe();
                    try {
                        sock = tcpServerSock.accept();
                    } catch (SocketTimeoutException e) {
                        continue;
                    } catch (IOException e) {
                        breathe();
                        fatalError(e);
                        return;
                    }
                    break;
                }
                InputStream stream;
                try {
                    sock.setSoTimeout(TIMEOUT);
                    stream = sock.getInputStream();
                } catch (IOException e) {
                    fatalError(e);
                    return;
                }
                byte header = readOne(stream);
                if (header != (byte) 'H') {
                    fatalError("Expecting 'H', received chr " + (int) header);
                }
                int device_i;
                byte b0 = readOne(stream);
                byte b1 = readOne(stream);
                if (b0 == (byte) 'F') {
                    device_i = DEVICE_FLUTE;
                } else { assert b0 == (byte) 'G';
                    if (b1 == (byte) 'L') {
                        device_i = DEVICE_GLOVE_L;
                    } else { assert b1 == (byte) 'R';
                        device_i = DEVICE_GLOVE_R;
                    }
                }
                if (tcp_socks[device_i] != null) {
                    fatalError(DEVICE_NAMES[device_i] + " connected twice!");
                }
                tcp_socks[device_i] = sock;
                udp_remote_addrs[device_i] = new InetSocketAddress(
                    sock.getInetAddress(), UDP_PORT
                );
                synchronized (handshake_stage) {
                    handshake_stage[device_i] = HandshakeStage.FINISHED;
                }
                tcpReceivers[device_i].start();
            }
            udpReceiver.start();
        }
    }

    private class UDPReceiver extends CaughtThread {
        public UDPReceiver() {
            super("UDPReceiver");
        }

        protected void caughtRun() {
            byte[] buf = new byte[BUF_SIZE];
            DatagramPacket packet = new DatagramPacket(buf, BUF_SIZE);
            while (true) {
                breathe();
                try {
                    udpSock.receive(packet);
                } catch (SocketTimeoutException e) {
                    continue;
                } catch (IOException e) {
                    breathe();
                    fatalError(e);
                }
                int len = packet.getLength();
                SocketAddress addr = packet.getSocketAddress();
                onRecv(len, buf, UDPorTCP.UDP, addr);
            }
        }
    }

    private class TCPReceiver extends CaughtThread {
        private int device_i;

        public TCPReceiver(int device_i) {
            super("TCPReceiver " + str(device_i));
            this.device_i = device_i;
        }

        protected void caughtRun() {
            InputStream stream;
            try {
                stream = tcp_socks[device_i].getInputStream();
            } catch (IOException e) {
                fatalError(e);
                return;
            }
            byte[] static_buf = new byte[3];
            while (true) {
                int packet_len = 3;
                byte[] buf = static_buf;
                for (int cursor = 0; cursor < packet_len; cursor ++) {
                    buf[cursor] = readOne(stream);
                    if (cursor == 3 - 1) {
                        if (buf[0] == (byte) 'L') {
                            int msg_len = decodePrintable(buf, 1);
                            packet_len = 3 + 1 + msg_len;
                            byte[] buf_L = new byte[packet_len];
                            buf_L[0] = buf[0];
                            buf_L[1] = buf[1];
                            buf_L[2] = buf[2];
                            buf = buf_L;
                        }
                    }
                }
                onRecv(packet_len, buf, UDPorTCP.TCP, null);
            }
        }
    }

    public Comm() {
        handshake_stage = new HandshakeStage[N_DEVICES];
        Arrays.fill(handshake_stage, HandshakeStage.OPENING);

        packet_T_intWriter = ByteBuffer.wrap(
            packetToSend_T, 0, PACKET_LEN_T
        ).order(ByteOrder.LITTLE_ENDIAN);
        packet_N_intWriter = ByteBuffer.wrap(
            packetToSend_N, 0, PACKET_LEN_N
        ).order(ByteOrder.LITTLE_ENDIAN);
        
        if (DEBUGGING_NO_ESP32)
            return;

        udp_remote_addrs = new SocketAddress[N_DEVICES];
        tcp_socks = new Socket[N_DEVICES];
        tcpReceivers = new TCPReceiver[N_DEVICES];

        logger = new Logger();
        tcpAccepter = new TCPAccepter();
        for (int i = 0; i < N_DEVICES; i ++) {
            tcpReceivers[i] = new TCPReceiver(i);
        }
        udpReceiver = new UDPReceiver();

        InetSocketAddress udp_host_addr = new InetSocketAddress(HOST_IP, UDP_PORT);
        InetSocketAddress tcp_host_addr = new InetSocketAddress(HOST_IP, HOST_TCP_PORT);
        try {
            udpSock = new DatagramSocket(null);
            udpSock.bind(udp_host_addr);
            udpSock.setSoTimeout(TIMEOUT);

            tcpServerSock = new ServerSocket();
            tcpServerSock.bind(tcp_host_addr, N_DEVICES);
            tcpServerSock.setSoTimeout(TIMEOUT);
        } catch (IOException e) {
            println("Hint: Is the laptop hotspot on?");
            fatalError(e);
        }

        packetToSend_T[0] = (byte) 'T';
        packetToSend_S[0] = (byte) 'S';
        packetToSend_D[0] = (byte) 'D';
        packetToSend_r[0] = (byte) 'r';
        packetToSend_C[0] = (byte) 'C';
        packetToSend_P[0] = (byte) 'P';
        packetToSend_M[0] = (byte) 'M';
        packetToSend_A[0] = (byte) 'A';
        packetToSend_O[0] = (byte) 'O';
        packetToSend_N[0] = (byte) 'N';
        packetToSend_L[0] = (byte) 'L';
        packetToSend_W[0] = (byte) 'W';
        packetToSend_B[0] = (byte) 'B';

        logger.start();
        tcpAccepter.start();
    }

    private int whoIsThis(SocketAddress addr) {
        for (int i = 0; i < N_DEVICES; i ++) {
            if (addr.equals(udp_remote_addrs[i]))
                return i;
        }
        fatalError("Got packet from stranger.");
        return -1;
    }
    
    private synchronized void onRecv(
        int len, byte[] buf, UDPorTCP udpOrTcp, 
        SocketAddress udp_remote_addr
    ) {
        boolean already_logged = false;
        byte header = buf[0];
        switch ((char) header) {
            case 'T': {
                System.arraycopy(
                    buf, 1, 
                    packetToSend_T, 1, 
                    4
                );
                packet_T_intWriter.putLong(5, (long) millis() * 1000);
                // testing showed in Processing, `Instant.now()` has only millisecond precision. 
                DatagramPacket packet = sendUDPNoLog(
                    packetToSend_T, PACKET_LEN_T, udp_remote_addr
                );
                int device_i = whoIsThis(udp_remote_addr);
                rtt[device_i] = ByteBuffer.wrap(buf, 5, 4).order(
                    ByteOrder.LITTLE_ENDIAN
                ).getInt() / 1000;
                logger.add(len, buf, RecvOrSend.RECV, udpOrTcp, device_i);
                already_logged = true;
                logger.add(
                    packet.getLength(), packet.getData(), 
                    RecvOrSend.SEND, udpOrTcp, device_i
                );
                break;
            }
            case 'F':
                if (redirect_bang) {
                    sceneSyncLatency.bang();
                    break;
                }
                hardware.onFingerChange(
                    decodeDigit(buf[1]), (char) buf[2]
                );
                assert len == 3;
                break;
            case 'P':
                if (HAS_PEDAL) {
                    onPedalSignal((char) buf[1]);
                }
                assert len == 2;
                break;
            case 'N':
                int pitch = decodePrintable(buf, 1);
                hardware.onNoteEvent(pitch);
                assert len == 3;
                break;
            case 'R':
                hardware.onCalibrateAtmosFinish();
                assert len == 3;
                break;
            case 'S':
                hardware.onResidualPressure((int) buf[1]);
                assert len == 2;
                break;
            case 'L':
                int msg_len = decodePrintable(buf, 1);
                print("Log from ESP32 [");
                print((char) buf[3]);
                print("]: ");
                println(new String(
                    buf, 4, msg_len, StandardCharsets.US_ASCII
                ));
                break;
            default:
                fatalError("Unknown ardu -> proc header: chr " + str(int(header)));
        }
        if (! already_logged) {
            logger.add(len, buf, RecvOrSend.RECV, udpOrTcp, -1);
        }
    }

    private int decodeDigit(byte c) {
        return (int) c - (int) '0';
    }
    private int decodePrintable(byte[] buf, int offset) {
        return 95 * ((int) buf[offset] - 32) + (int) buf[offset + 1] - 32;
    }

    public void sendUDP(byte[] buf, int len, int device_i) {
        if (DEBUGGING_NO_ESP32)
            return;
        DatagramPacket packet = sendUDPNoLog(buf, len, udp_remote_addrs[device_i]);
        logger.add(len, buf, RecvOrSend.SEND, UDPorTCP.UDP, device_i);
    }
    private DatagramPacket sendUDPNoLog(byte[] buf, int len, SocketAddress addr) {
        DatagramPacket packet = new DatagramPacket(
            buf, len, addr
        );
        try {
            synchronized (this) {
                udpSock.send(packet);
            }
        } catch (IOException e) {
            fatalError(e);
        }
        return packet;
    }
    public void sendTCP(byte[] buf, int len, int device_i) {
        if (DEBUGGING_NO_ESP32)
            return;
        try {
            tcp_socks[device_i].getOutputStream().write(buf, 0, len);
        } catch (IOException e) {
            fatalError(e);
        }
        logger.add(len, buf, RecvOrSend.SEND, UDPorTCP.TCP, device_i);
    }
    
    private boolean caughtJoin(Thread t) {
        if (t == null)
            return false;
        try {
            t.join(TIMEOUT * 3);
        } catch (InterruptedException e) {
            printStackTrace(e);
        }
        if (t.isAlive()) {
            println("thread.join timeout.");
        } else {
            println("thread joined.");
        }
        return true;
    }

    public void close() {
        if (DEBUGGING_NO_ESP32)
            return;
        should_exit = true;
        if (caughtJoin(logger)) {
            logger.close();
        }
        caughtJoin(udpReceiver);
        shutclose(udpSock);
        for (int i = 0; i < N_DEVICES; i ++) {
            caughtJoin(tcpReceivers[i]);
            shutclose(tcp_socks[i]);
        }
        shutclose(tcpServerSock);
    }

    public HandshakeStage getHandshakeStage(int device_i) {
        synchronized (handshake_stage) {
            return handshake_stage[device_i];
        }
    }

    private void onPedalSignal(char state) {
        if (session.stage == SessionStage.PLAYING) {
            session.onPedalSignal(state);
        }
    }

    private void encodeTwoChars(int angle, byte[] buf, int offset) {
        buf[offset]     = (byte) (angle / 127 + 1);
        buf[offset + 1] = (byte) (angle % 127 + 1);
    }

    private byte encodeDigit(int digit) {
        // look! when digit <= 9, it behaves like str()! 
        int result = digit + (int) '0';
        if (result >= 127) {
            fatalError("encodeDigit() input too large");
        }
        return (byte) result;
    }

    private void writeServoID(int servo_id, byte[] buf, int offset) {
        if (servo_id < 3) {
            buf[offset] = (byte) 'L';
        } else {
            buf[offset] = (byte) 'R';
            servo_id -= 3;
        }
        buf[offset + 1] = (byte) ((int) '0' + servo_id + 2);
    }

    public char encodeFingers(char[] fingers) {
        // remember serial byte range is [1, 127]
        // let's use [64, 127]
        int acc = 1;
        for (int i = 0; i < 6; i ++) {
            acc <<= 1;
            if (fingers[i] == '_') {
                acc |= 1;
            }
        }
        return (char) acc;
    }

    private void writeRestablePitch(
        MusicNote restablePitch, byte[] buf, int offset
    ) {
        if (restablePitch.is_rest) {
            buf[offset] = (byte) 't';
        } else {
            buf[offset] = (byte) 'f';
            buf[offset + 1] = (byte) restablePitch.pitch;
        }
    }

    public void send_B(int device_i) {
        byte[] buf = packetToSend_B;
        sendTCP(buf, PACKET_LEN_B, device_i);
    }
    public void send_S(int servo_id, int angle, int device_i) {
        byte[] buf = packetToSend_S;
        writeServoID(servo_id, buf, 1);
        encodeTwoChars(angle, buf, 3);
        sendUDP(buf, PACKET_LEN_S, device_i);
    }
    public void send_D(int servo_id, int device_i) {
        byte[] buf = packetToSend_D;
        writeServoID(servo_id, buf, 1);
        encodeTwoChars(angle_config[servo_id + 1 * 6], buf, 3);
        buf[5] = encodeDigit(Parameter.Hint.slow);
        sendUDP(buf, PACKET_LEN_D, device_i);
    }
    public void send_C(int x, int device_i) {
        byte[] buf = packetToSend_C;
        buf[1] = (byte) x;
        sendTCP(buf, PACKET_LEN_C, device_i);
    }
    public void send_P(int device_i) {
        byte[] buf = packetToSend_P;
        encodeTwoChars(20, buf, 1);
        sendTCP(buf, PACKET_LEN_P, device_i);
    }
    public void send_M(boolean value, int device_i) {
        byte[] buf = packetToSend_M;
        buf[1] = (byte) (value ? 't' : 'f');
        sendTCP(buf, PACKET_LEN_M, device_i);
    }
    public void send_A(AutoPOFMode mode, int device_i) {
        byte[] buf = packetToSend_A;
        buf[1] = (byte) mode.id;
        sendTCP(buf, PACKET_LEN_A, device_i);
    }
    public void send_O(MusicNote restablePitch, int device_i) {
        byte[] buf = packetToSend_O;
        writeRestablePitch(restablePitch, buf, 1);
        sendTCP(buf, PACKET_LEN_O, device_i);
    }
    public void send_N(
        CommWhichQueue which, long time, 
        MusicNote restablePitch, int device_i
    ) {
        byte[] buf = packetToSend_N;
        buf[1] = (byte) (char) which.getID();
        packet_N_intWriter.putLong(2, time);
        writeRestablePitch(restablePitch, buf, 10);
        sendTCP(buf, PACKET_LEN_N, device_i);
    }
    public void send_L(CommWhichQueue which, int device_i) {
        byte[] buf = packetToSend_L;
        buf[1] = (byte) (char) which.getID();
        sendTCP(buf, PACKET_LEN_L, device_i);
    }
    public void send_W(int device_i) {
        byte[] buf = packetToSend_W;
        sendTCP(buf, PACKET_LEN_W, device_i);
    }
    public void send_r(int device_i) {
        byte[] buf = packetToSend_r;
        sendTCP(buf, PACKET_LEN_r, device_i);
    }
}
