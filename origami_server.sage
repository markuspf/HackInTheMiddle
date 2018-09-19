import socket
try:
    import socketserver
except:
    import SocketServer as socketserver
import logging
from openmath import openmath as om, convert as conv

from scscp.client import TimeoutError, CONNECTED
from scscp.server import SCSCPServer
from scscp.scscp import SCSCPQuit, SCSCPProtocolError
from scscp import scscp

from surface_dynamics.all import *

# Supported functions
CD_SCSCP2 = ['get_service_description', 'get_allowed_heads', 'is_allowed_head']

def veech_group_of_origami(g1, g2):
    print("Computing veech group of origami %s %s\n" % (g1, g2))
    o = Origami(g1,g2)
    g = o.veech_group()
    print("Done\n")
    return [ g.S2(), g.L() ]

def gap_element_to_om(ge):
    if gap.IsPerm(ge):
        imgs = [conv.to_openmath(int(i)) for i in list(gap.ListPerm(ge))]
        return om.OMApplication(om.OMSymbol('permutation', 'permut1'), imgs)

def perm_to_om(p):
    imgs = [conv.to_openmath(int(i)) for i in p.tuple()]
    return om.OMApplication(om.OMSymbol('permutation', 'permut1'), imgs)
    
# register_to_openmath()
conv.register_to_python('permut1', 'permutation', lambda imgs: gap.PermList([conv.to_python(i) for i in imgs.arguments]))
conv.register_to_python('scscp_transient_1', 'veech_group_of_origami', veech_group_of_origami)

conv.register_to_openmath(sage.interfaces.gap.GapElement, gap_element_to_om)
conv.register_to_openmath(sage.groups.perm_gps.permgroup_element.PermutationGroupElement, perm_to_om)

CD_SCSCP_TRANSIENT_1 = {
    'veech_group_of_origami': veech_group_of_origami
}

class SCSCPRequestHandler(socketserver.BaseRequestHandler):
    def setup(self):
        self.server.log.info("New connection from %s:%d" % self.client_address)
        self.log = self.server.log.getChild(self.client_address[0])
        self.scscp = SCSCPServer(self.request, self.server.name,
                                     self.server.version, logger=self.log)
        
    def handle(self):
        self.scscp.accept()
        while True:
            try:
                call = self.scscp.wait()
            except TimeoutError:
                continue
            except SCSCPQuit as e:
                self.log.info(e)
                break
            except ConnectionResetError:
                self.log.info('Client closed unexpectedly.')
                break
            except SCSCPProtocolError as e:
                self.log.info('SCSCP protocol error: %s.' % str(e))
                self.log.info('Closing connection.')
                self.scscp.quit()
                break
            self.handle_call(call)

    def handle_call(self, call):
        if (call.type != 'procedure_call'):
            raise SCSCPProtocolError('Bad message from client: %s.' % call.type, om=call.om())
        try:
            head = call.data.elem.name
            self.log.debug('Requested head: %s...' % head)
            
            if call.data.elem.cd == 'scscp2' and head in CD_SCSCP2:
                res = getattr(self, head)(call.data)
            elif call.data.elem.cd == 'scscp_transient_1' and head in CD_SCSCP_TRANSIENT_1:
                args = [conv.to_python(a) for a in call.data.arguments]
                res = conv.to_openmath(CD_SCSCP_TRANSIENT_1[head](*args))
            else:
                self.log.debug('...head unknown.')
                return self.scscp.terminated(call.id, om.OMError(
                    om.OMSymbol('unhandled_symbol', cd='error'), [call.data.elem]))

            strlog = str(res)
            self.log.debug('...sending result: %s' % (strlog[:20] + (len(strlog) > 20 and '...')))
            return self.scscp.completed(call.id, res)
        except (AttributeError, IndexError, TypeError):
            self.log.debug('...client protocol error.')
            return self.scscp.terminated(call.id, om.OMError(
                om.OMSymbol('unexpected_symbol', cd='error'), [call.data]))
        except Exception as e:
            self.log.exception('Unhandled exception:')
            return self.scscp.terminated(call.id, 'system_specific',
                                             'Unhandled exception %s.' % str(e))

    def get_allowed_heads(self, data):
        return scscp.symbol_set([om.OMSymbol(head, cd='scscp2') for head in CD_SCSCP2]
                                    + [om.OMSymbol(head, cd='scscp_transient_1') for head in CD_SCSCP_TRANSIENT_1],
                                    cdnames=['scscp1'])
    
    def is_allowed_head(self, data):
        head = data.arguments[0]
        return conv.to_openmath((head.cd == 'scscp2' and head.name in CD_SCSCP2)
                                    or (head.cd == 'scscp_transient_1' and head.name in CD_SCSCP_TRANSIENT_1)
                                    or head.cd == 'scscp1')

    def get_service_description(self, data):
        return scscp.service_description(self.server.name.decode(),
                                             self.server.version.decode(),
                                             self.server.description)

class Server(socketserver.ThreadingMixIn, socketserver.TCPServer, object):
    allow_reuse_address = True
    
    def __init__(self, host='localhost', port=26133,
                     logger=None, name=b'DemoServer', version=b'none',
                     description='Demo SCSCP server'):
        super(Server, self).__init__((host, port), SCSCPRequestHandler)
        self.log = logger or logging.getLogger(__name__)
        self.name = name
        self.version = version
        self.description = description
        
if __name__ == '__main__':
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger('demo_server')
    srv = Server(logger=logger)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.shutdown()
srv.server_close()
