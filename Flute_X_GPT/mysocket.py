'''
My socket utils. Provides `recvall`, `recvFile`, `sendFileJdt`, and `findAPort`.  
'''
from __future__ import annotations

from typing import *
import os
from os.path import getsize
from time import time
from socket import socket, timeout as SocketTimeout
import jdt
from pickle_socket import PickleSocket
from interactive import inputUntilValid, inputChin

PAGE = 4096
RUSH = 128
RUSHxPAGE = RUSH * PAGE

def recvFile(s, file_len, to_filename, accept_double_dot = False):
    '''
    receive a file from a socket with known length. 
    '''
    assert type(s) is socket
    if not accept_double_dot and ('../' in to_filename or '..\\' in to_filename):
        raise ValueError('../ in filename. Is there a hacker?')
    j = jdt.CommJdt(file_len, msg = to_filename)
    with open(to_filename, 'wb+') as to_file:
        left = file_len
        while left:
            for _ in range(RUSH):
                left -= to_file.write(s.recv(min(left, PAGE)))
            recved = s.recv(min(left, PAGE))
            if recved == b'':
                if left:
                    assert False
            else:
                left -= to_file.write(recved)
                j.update(file_len - left)
        j.complete()

def recvall(s: socket, size: int, *args, **kw):
    """
    Receive `size` bytes from socket `s`.  
    Fully blocking. Does not support timeout.  
    """
    # def warnLegacy():
    #     print('Warning: You are using the legacy signature of recvall.')
    # try:
    #     kw['timeout'] = args[0]
    # except IndexError:
    #     pass
    # try:
    #     kw['dt'] = args[1]
    # except IndexError:
    #     pass
    # try:
    #     timeout = kw['timeout']
    # except KeyError:
    #     pass
    # else:
    #     warnLegacy()
    #     if timeout is None:
    #         return recvall(s, size)
    #     else:
    #         raise NotImplementedError('Exact timeout behavior of legacy not well-defined.')
    # if 'dt' in kw:
    #     warnLegacy()

    assert s.timeout is None
    buffer = memoryview(bytearray(size))
    cursor = 0
    while cursor != size:
        n_bytes_recved = s.recv_into(buffer[cursor:], size - cursor)
        if n_bytes_recved == 0:
            raise EOFError(f'Socket {s} remote closed. ')
        cursor += n_bytes_recved
    return buffer.tobytes()

def recvallintoWithTimeout(
    s: socket, size: int, buffer: memoryview, cursor: List[int], 
):
    """
    Receive `size` bytes from socket `s` into `buffer`.  
    `s.timeout` is used as the overall timeout.  
    Note that if timeout occurs, some bytes may have been consumed and not available in the socket. You can recover the state by examining `cursor[0]` and the partially-filled `buffer`.  
    """
    cursor[0] = 0
    timeout = s.timeout
    assert timeout is not None
    deadline = time() + timeout
    try:
        while cursor[0] != size:
            s.settimeout(deadline - time())
            n_bytes_recved = s.recv_into(buffer[cursor[0]:], size - cursor[0])
            if n_bytes_recved == 0:
                raise EOFError(f'Socket {s} remote closed. ')
            cursor[0] += n_bytes_recved
    finally:
        s.settimeout(timeout)

def sendFileJdt(s, file, msg = 'send'):
    assert type(s) is socket
    save_pos = file.tell()
    total = file.seek(0, os.SEEK_END)
    if not total:
        print('mysocket Warning: file.seek did not return file size, using plan B. Daniel: change it to `seek() or tell()`')
        total = file.tell()
    file.seek(save_pos)
    j = jdt.CommJdt(total, msg = msg)
    estimated_sent = 0
    read = None
    while read != b'':
        if estimated_sent > total:
            print('mysocket warning: OMG it actually happens! estimation drifted up! ')
        else:
            j.update(estimated_sent)
        for i in range(RUSH):
            read = file.read(PAGE)
            s.sendall(read)
        estimated_sent += RUSHxPAGE
    j.complete()

def findAPort(hostname = 'localhost', search_range = range(3000, 4000)):
    '''
    finds an available port in `range`, default 3000~4000.  
    Returns (socket, port), where socket is binded but not listening.  
    '''
    for port in search_range:
        serverSock = socket()
        try:
            serverSock.bind((hostname, port))
            return (serverSock, port)
        except OSError:
            serverSock.close()
    raise RuntimeError('No port available in range.')

def pair(port, host_ip = 'localhost', handshake_msg = 'mysocket.pair'):
    '''
    Establish pickleSocket pair with minimum security (asks user to confirm IP)  
    '''
    role = inputUntilValid('Client or Server?', 'cs')
    s = PickleSocket()
    if role == 's':
        s.bind((host_ip, port))
        s.listen(1)
        print(f'Waiting for connection @ {host_ip}:{port}...')
        cs, addr = s.accept()
        print('Connection from', addr)
        if inputUntilValid('Accept?', 'yn') != 'y':
            cs.close()
            s.close()
            raise ConnectionRefusedError
        cs.shakeHands(handshake_msg)
        s.close()
        return 's', cs, addr[0]
    elif role == 'c':
        ip = inputChin('IP = ', 'localhost')
        s.connect((ip, port))
        print('Waiting for server to accept...')
        try:
            s.shakeHands(handshake_msg)
        except ConnectionResetError:
            s.close()
            raise ConnectionRefusedError
        return 'c', s, ip

def shipFile(role, s:PickleSocket, filename):
    assert role in 'sr'
    if role == 's':
        s.sendObj(filename)
        s.sendObj(getsize(filename))
        with open(filename, 'rb') as f:
            sendFileJdt(s.socket, f, msg=filename)
    elif role == 'r':
        filename = s.recvObj()
        size = s.recvObj()
        recvFile(s.socket, size, filename)

if __name__ == '__main__':
    pair(2333)
