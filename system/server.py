"""
echo_8051 Peripheral Demo — Flask server.
Timer0 interrupt rotates LEDs on P1.
UART echo terminal + button for INT0.
"""
import sys, os, time, threading
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))

from flask import Flask, render_template, request, jsonify
from python.echo_8051 import Echo8051

app = Flask(__name__)

# ===== 8051 Demo Program =====
# Vectors: LJMP MAIN at 0x00, LJMP ISR_TIMER0 at 0x0B
PROG = bytearray(256)
def rom(addr, *data):
    for i, b in enumerate(data): PROG[addr+i] = b

# Reset vector
rom(0x00, 0x02,0x00,0x30)              # LJMP MAIN (0x0030)
# Timer0 vector
rom(0x0B, 0x02,0x00,0x80)              # LJMP ISR_TIMER0 (0x0080)

# ==== MAIN (0x0030) ====
rom(0x30,
    0x75,0xA8,0x82,    # MOV IE, #0x82  (EA+ET0)
    0x75,0x89,0x01,    # MOV TMOD, #0x01 (T0 mode 1)
    0x75,0x8C,0xFF,    # MOV TH0, #0xFF  (fast overflow)
    0x75,0x8A,0x00,    # MOV TL0, #0x00
    0x75,0x88,0x10,    # MOV TCON, #0x10 (TR0=1)
    0x74,0x01,         # MOV A, #0x01
    0xF5,0x90,         # MOV P1, A
    # idle loop
    0x80,0xFE)         # SJMP $  (wait for interrupt)

# ==== ISR_TIMER0 (0x0080) ====
rom(0x80,
    0x75,0x8C,0xFF,    # MOV TH0, #0xFF (reload)
    0x75,0x8A,0x00,    # MOV TL0, #0x00
    0xE5,0x90,         # MOV A, P1
    0x23,              # RL A
    0xF5,0x90,         # MOV P1, A
    0x32)              # RETI

PROG_BYTES = bytes(PROG)

# ===== Server State =====
cpu = Echo8051(256)
running = False
bg_thread = None
uart_rx_buf = []
uart_tx_buf = []

def bg_loop():
    global running, cpu
    while running:
        try:
            if uart_rx_buf:
                cpu.uart_receive(uart_rx_buf.pop(0))
            cpu.run(max_instructions=500)
            # Check UART TX
            scon = cpu.mem.read_sfr(0x98)
            if scon & 0x02:
                tx_byte = cpu.mem.read_sfr(0x99)
                uart_tx_buf.append(tx_byte)
                cpu.mem.write_sfr(0x98, scon & ~0x02)
        except Exception:
            pass
        time.sleep(0.02)

# ==== Routes ====
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/state')
def api_state():
    if cpu is None: return jsonify({'p1':0,'running':False})
    return jsonify({
        'p1': cpu.read_port(1),
        'p3': cpu.read_port(3),
        'acc': cpu.acc, 'psw': cpu.psw, 'pc': cpu.get_pc(), 'sp': cpu.mem.sp,
        'ie': cpu.mem.ie, 'tcon': cpu.mem.tcon,
        'th0': cpu.mem.read_sfr(0x8C), 'tl0': cpu.mem.read_sfr(0x8A),
        'scon': cpu.mem.scon, 'sbuf': cpu.mem.read_sfr(0x99),
        'uart_tx': uart_tx_buf[-20:] if uart_tx_buf else [],
        'running': running
    })

@app.route('/api/reset', methods=['POST'])
def api_reset():
    global running, bg_thread, cpu, uart_rx_buf, uart_tx_buf
    if running and bg_thread:
        running = False; bg_thread.join(timeout=1)
    uart_rx_buf.clear(); uart_tx_buf.clear()
    cpu = Echo8051(256); cpu.load_bytes(PROG_BYTES); cpu.write_port(1,0x00)
    running = True
    bg_thread = threading.Thread(target=bg_loop, daemon=True); bg_thread.start()
    return jsonify({'status':'ok'})

@app.route('/api/step', methods=['POST'])
def api_step():
    if cpu: cpu.step()
    return jsonify({'p1':cpu.read_port(1) if cpu else 0})

@app.route('/api/uart_send', methods=['POST'])
def api_uart_send():
    b = request.get_json().get('byte',0)&0xFF; uart_rx_buf.append(b)
    return jsonify({'sent':b})

@app.route('/api/speed', methods=['POST'])
def api_speed():
    reload_val = max(100, min(65000, int(request.get_json().get('reload',256))))
    high = (65536 - reload_val) >> 8; low = (65536 - reload_val) & 0xFF
    if cpu:
        cpu.mem.rom[0x81] = high; cpu.mem.rom[0x84] = low
    return jsonify({'reload':reload_val})

if __name__ == '__main__':
    cpu = Echo8051(256); cpu.load_bytes(PROG_BYTES); cpu.write_port(1,0x00)
    running = True
    bg_thread = threading.Thread(target=bg_loop, daemon=True); bg_thread.start()
    print("echo_8051 Peripheral Demo — http://127.0.0.1:5000")
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
