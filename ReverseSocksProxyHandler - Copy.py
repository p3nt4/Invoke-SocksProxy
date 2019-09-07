import socket
import sys
import thread
import time

def main(portHandler, portProxy):
    dock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    dock_socket.bind(('', int(portHandler)))
    dock_socket.listen(5)
    dock_socket2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    dock_socket2.bind(('', int(portProxy)))
    dock_socket2.listen(5)
    while True:
        client_socket = dock_socket.accept()[0]
        print("Reverse Socks Connection Recieved")
        client_socket2 = dock_socket2.accept()[0]
        print("Socks Connection Recieved")
        client_socket.send("HELLO")
        thread.start_new_thread(forward, (client_socket, client_socket2))
        thread.start_new_thread(forward, (client_socket2, client_socket))
        
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
    main(sys.argv[1], sys.argv[2])