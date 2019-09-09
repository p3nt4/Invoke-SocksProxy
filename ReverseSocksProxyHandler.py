import socket
import sys
import thread
import time
import ssl

def main(handlerPort,proxyPort,certificate,privateKey):
    thread.start_new_thread(server, (handlerPort,proxyPort,certificate,privateKey))
    while True:
       time.sleep(60)


def server(handlerPort,proxyPort,certificate,privateKey):
    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
    context.load_cert_chain(certificate,privateKey)
    try:
        dock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        dock_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        dock_socket.bind(('', int(handlerPort)))
        dock_socket.listen(5)
        print("Handler listening on: " + handlerPort)
        dock_socket2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        dock_socket2.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        dock_socket2.bind(('', int(proxyPort)))
        print("Socks Proxy listening on: " + proxyPort)
        dock_socket2.listen(5)
        while True:
            try:
                print("Waiting for Reverse Socks Connection")
                clear_socket = dock_socket.accept()[0]
                client_socket = context.wrap_socket(clear_socket, server_side=True)
                print("Reverse Socks Connection Received")
                client_socket2 = dock_socket2.accept()[0]
                print("Socks Connection Received")
                client_socket.send("HELLO")
                thread.start_new_thread(forward, (client_socket, client_socket2))
                thread.start_new_thread(forward, (client_socket2, client_socket))
            except:
                print("Error")
                pass
    finally:
        dock_socket.close()
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
        pass

if __name__ == '__main__':
    if len(sys.argv) < 5:
	    print("Usage:{} <handlerPort> <proxyPort> <certificate> <privateKey>".format(sys.argv[0]))
    else:
	    main(sys.argv[1], sys.argv[2],sys.argv[3],sys.argv[4])
