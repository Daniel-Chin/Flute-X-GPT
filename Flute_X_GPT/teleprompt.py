import socket
from threading import Thread
import time

from shared import *

IP = '192.168.137.1'

def main():
    with socket.socket() as accepter:
        accepter.bind(('', TELEPROMPT_PORT))
        accepter.listen(1)
        print(
            'listening for on port', 
            TELEPROMPT_PORT, '...', 
        )
        sock, addr = accepter.accept()
        print('connected from', addr)
        thread = Thread(target=echo, args=(sock,))
        thread.start()
        try:
            while True:
                op = input()
                try:
                    char = op[0]
                except IndexError:
                    char = '\n'
                try:
                    sock.sendall(char.encode('utf-8'))
                except (ConnectionAbortedError, ConnectionResetError):
                    break
        except (KeyboardInterrupt, EOFError):
            print('Bye')
        finally:
            sock.close()
            thread.join()
            print('thread joined')

def echo(sock: socket.socket):
    while True:
        try:
            data = sock.recv(1024)
        except (ConnectionAbortedError, ConnectionResetError):
            break
        if data == b'':
            break
        print(data.decode('utf-8'), end='', flush=True)

if __name__ == '__main__':
    main()
