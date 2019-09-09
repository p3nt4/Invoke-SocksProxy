import socket
import sys
import thread
import time
import ssl

def main(handlerPort,proxyPort):
    thread.start_new_thread(server, (handlerPort,proxyPort))
    while True:
       time.sleep(60)


def server(handlerPort,proxyPort):
    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
    context.load_cert_chain('./cert.pem', './private.key')
    try:
        dock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        dock_socket.bind(('', int(handlerPort)))
        dock_socket.listen(5)
        print("Handler listening on: " + handlerPort)
        dock_socket2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        dock_socket2.bind(('', int(proxyPort)))
        print("Socks Proxy listening on: " + proxyPort)
        dock_socket2.listen(5)
        while True:
            try:
                clear_socket = dock_socket.accept()[0]
                client_socket = context.wrap_socket(clear_socket, server_side=True)
                print("Reverse Socks Connection Received")
                client_socket2 = dock_socket2.accept()[0]
                print("Socks Connection Received")
                client_socket.send("HELLO")
                thread.start_new_thread(forward, (client_socket, client_socket2))
                thread.start_new_thread(forward, (client_socket2, client_socket))
            except:
                time.sleep(200)
                pass
    finally:
        time.sleep(200)
        thread.start_new_thread(server, (handlerPort,proxyPort))

def forward(source, destination):
    string = ' '
    while string:
        string = source.recv(1024)
        if string:
            destination.sendall(string)
        else:
            source.shutdown(socket.SHUT_RD)
            destination.shutdown(socket.SHUT_WR)

if __name__ == '__main__':
    if len(sys.argv) < 3:
	    print("Usage:{} <handlerPort> <proxyPort>".format(sys.argv[0]))
    else:
	    main(sys.argv[1], sys.argv[2])
