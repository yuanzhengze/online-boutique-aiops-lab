"""部署v4-final - flush输出"""
import paramiko, socket, os, time, sys

h = 'svr-1.mc.nankai.club'
k = paramiko.Ed25519Key.from_private_key_file(os.path.expanduser(r'C:\Users\Lenovo\.ssh\id_ed25519'))
s = socket.socket(); s.settimeout(30); s.connect((h, 1919))
t = paramiko.Transport(s); t.connect(username='collaborator', pkey=k)
print('SSH连接成功', flush=True)

def run(cmd, timeout=10):
    c = t.open_session(); c.exec_command(cmd + ' 2>&1')
    d = b''; c.settimeout(timeout)
    try:
        while True:
            chunk = c.recv(4096)
            if not chunk: break
            d += chunk
    except socket.timeout: pass
    return d.decode('utf-8', errors='replace').strip()

def sftp_put(local_path, remote_path):
    sf = t.open_sftp_client()
    try:
        sf.put(local_path, remote_path)
    finally:
        sf.close()

# 1. 杀旧进程
print('=== 杀旧进程 ===', flush=True)
run('pkill -9 -f chaos_loop 2>/dev/null')
time.sleep(2)

# 2. 上传脚本
print('=== 上传脚本 ===', flush=True)
sftp_put(r'd:\DDesk\aiops-lab-work\chaos_loop_v4_final.sh', '/tmp/chaos_loop_v4_final.sh')
run('chmod +x /tmp/chaos_loop_v4_final.sh')
print('已上传', flush=True)

# 3. 启动
print('=== 启动v4-final ===', flush=True)
c = t.open_session()
c.exec_command('nohup bash /tmp/chaos_loop_v4_final.sh > /tmp/chaos_loop_v4_final.log 2>&1 &')
time.sleep(1)
c.close()

print('等待15秒...', flush=True)
time.sleep(15)

# 4. 验证
print('=== 验证 ===', flush=True)
procs = run('ps aux | grep chaos_loop_v4_final | grep -v grep')
print(f'进程: {procs}', flush=True)

log = run('head -15 /tmp/chaos_loop_v4_final.log 2>/dev/null')
print(f'日志:\n{log}', flush=True)

csv = run('cat /tmp/chaos_timeline_v4_final.csv 2>/dev/null')
print(f'CSV:\n{csv}', flush=True)

t.close()
print('=== v4-final 部署完成! ===', flush=True)
