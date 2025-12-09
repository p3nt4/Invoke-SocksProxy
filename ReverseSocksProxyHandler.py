import socket
import sys
import _thread
import time
import ssl
import queue


def main(handlerPort, proxyPort, certificate, privateKey):
    _thread.start_new_thread(server, (handlerPort, proxyPort, certificate, privateKey))
    while True:
        time.sleep(60)


def handlerServer(q, handlerPort, certificate, privateKey):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certificate, privateKey)
    try:
        dock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        dock_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        dock_socket.bind(('', int(handlerPort)))
        dock_socket.listen(5)
        print("Handler listening on: " + handlerPort)
        while True:
            try:
                clear_socket, address = dock_socket.accept()
                client_socket = context.wrap_socket(clear_socket, server_side=True)
                print("Reverse Socks Connection Received: {}:{}".format(address[0], address[1]))
                try:
                    data = b""
                    while (data.count(b'\n') < 3):
                        data_recv = client_socket.recv()
                        data += data_recv
                    client_socket.send(
                        b"HTTP/1.1 200 OK\nContent-Length: 999999\nContent-Type: text/plain\nConnection: Keep-Alive\nKeep-Alive: timeout=20, max=10000\n\n")
                    q.get(False)
                except Exception as e:
                    pass
                q.put(client_socket)
            except Exception as e:
                print(e)
                pass
    except Exception as e:
        print(e)
    finally:
        dock_socket.close()


def getActiveConnection(q):
    try:
        client_socket = q.get(block=True, timeout=10)
    except:
        print('No Reverse Socks connection found')
        return None
    try:
        client_socket.send(b"HELLO")
    except:
        return getActiveConnection(q)
    return client_socket


def server(handlerPort, proxyPort, certificate, privateKey):
    q = queue.Queue()
    _thread.start_new_thread(handlerServer, (q, handlerPort, certificate, privateKey))
    try:
        dock_socket2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        dock_socket2.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        dock_socket2.bind(('127.0.0.1', int(proxyPort)))
        dock_socket2.listen(5)
        print("Socks Server listening on: " + proxyPort)
        while True:
            try:
                client_socket2, address = dock_socket2.accept()
                print("Socks Connection Received: {}:{}".format(address[0], address[1]))
                client_socket = getActiveConnection(q)
                if client_socket == None:
                    client_socket2.close()
                _thread.start_new_thread(forward, (client_socket, client_socket2))
                _thread.start_new_thread(forward, (client_socket2, client_socket))
            except Exception as e:
                print(e)
                pass
    except Exception as e:
        print(e)
    finally:
        dock_socket2.close()


def forward(source, destination):
    try:
        string = ' '
        while string:
            string = source.recv(1024)
            if string:
                destination.sendall(string)
            else:
                source.shutdown(socket.SHUT_RD)
                destination.shutdown(socket.SHUT_WR)
    except:
        try:
            source.shutdown(socket.SHUT_RD)
            destination.shutdown(socket.SHUT_WR)
        except:
            pass
        pass


if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Usage:{} <handlerPort> <proxyPort> <certificate> <privateKey>".format(sys.argv[0]))
    else:
        main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
