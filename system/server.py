"""
echo_8051 Running Light — Flask web server.
Browser shows 8 LEDs driven by P1 port of 8051 ISS.
"""
import sys, os, time, threading
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'model'))

from flask import Flask, render_template, request, jsonify
from python.echo_8051 import Echo8051

app = Flask(__name__)
running = False
bg_thread = None

# ==== 8051 LED Program (runs from ROM address 0) ====
# Uses P1 for 8 LEDs. Delay via nested R0×R1 loop.
# Rotates: 0x01→0x02→0x04→0x08→0x10→0x20→0x40→0x80
LED_PROG = bytes([
    0x75,0x90,0x00,     # 00: MOV P1,#0     (all LEDs off)
    0x74,0x01,           # 03: MOV A,#1      (first LED)
    # ==== main_loop ====
    0xF5,0x90,           # 05: MOV P1,A      (output to LEDs)
    0x78,0x05,           # 07: MOV R0,#5     (outer delay)
    0x79,0x10,           # 09: MOV R1,#16    (inner delay)
    0x00,                # 0B: NOP           (delay_inner:)
    0xD9,0xFD,           # 0C: DJNZ R1,delay_inner [rel=0x0B-0x0E=-3=0xFD]
    0xD8,0xF9,           # 0E: DJNZ R0,delay_outer [rel=0x09-0x10=-7=0xF9]
    0x23,                # 10: RL A          (next LED)
    0x80,0xF2,           # 11: SJMP main_loop [rel=0x05-0x13=-14=0xF2]
])

def init_cpu():
    global cpu
    cpu = Echo8051(256)
    cpu.load_bytes(LED_PROG)
    cpu.write_port(1, 0x00)
    return cpu

def bg_loop():
    global running, cpu
    while running:
        try:
            cpu.run(max_instructions=500)
        except Exception:
            pass
        time.sleep(0.03)

# ==== Routes ====

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/reset', methods=['POST'])
def api_reset():
    global running, bg_thread, cpu
    if running and bg_thread:
        running = False
        bg_thread.join(timeout=1)
    cpu = init_cpu()
    running = True
    bg_thread = threading.Thread(target=bg_loop, daemon=True)
    bg_thread.start()
    return jsonify({'status': 'ok'})

@app.route('/api/state')
def api_state():
    return jsonify({
        'p1': cpu.read_port(1) if cpu else 0,
        'p3': cpu.read_port(3) if cpu else 0xFF,
        'acc': cpu.acc if cpu else 0,
        'psw': cpu.psw if cpu else 0,
        'pc': cpu.get_pc() if cpu else 0,
        'running': running
    })

@app.route('/api/speed', methods=['POST'])
def api_speed():
    data = request.get_json()
    speed = max(1, min(255, int(data.get('speed', 32))))
    if cpu: cpu.mem.rom[8] = speed  # ROM addr 8 = R0 delay counter
    return jsonify({'speed': speed})

@app.route('/api/step', methods=['POST'])
def api_step():
    if cpu:
        cpu.step()
        return jsonify({'p1': cpu.read_port(1), 'pc': cpu.get_pc()})
    return jsonify({'error': 'not initialized'}), 400

@app.route('/api/button', methods=['POST'])
def api_button():
    data = request.get_json()
    pressed = data.get('pressed', False)
    if cpu:
        p3 = cpu.read_port(3)
        cpu.write_port(3, (p3 & ~1) if pressed else (p3 | 1))
    return jsonify({'p3': cpu.read_port(3) if cpu else 0xFF})

if __name__ == '__main__':
    cpu = Echo8051(256)
    cpu.load_bytes(LED_PROG)
    cpu.write_port(1, 0x00)
    running = True
    bg_thread = threading.Thread(target=bg_loop, daemon=True)
    bg_thread.start()
    print("echo_8051 Running Light — http://127.0.0.1:5000")
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
