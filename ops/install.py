import subprocess
import time
import shlex
import ipaddress
import logging


logging.basicConfig(filename='example.log', level=logging.DEBUG)
INVEN_FILE = '/tmp/inventry'
HOSTS_FILE = '/tmp/hosts'


def check_ip(ip):
    try:
        ipaddress.ip_address(unicode(ip))
    except Exception, e:
        print e
        return False
    return True


def main():
    controller_ip = raw_input("please input controller ip:")
    # check the ip invalid
    if not check_ip(controller_ip):
        print "IP has error"
        return
    compute_ips = []
    index = 1
    while 1:
        com_ip = raw_input("please input compute %s ip:" % index)
        if not check_ip(com_ip):
            continue
        compute_ips.append(com_ip)
        break_word = raw_input("Please input y to break input compute:")
        if break_word == 'y':
            break
        index += 1
    generate_config(controller_ip, compute_ips)
    # begin to start ansible call
    # cmd = (
    #    'ansible-playbook -i %s ./config_hostname.yml -e '
    #    'hosts_file=%s' % (INVEN_FILE, HOSTS_FILE))
    cmd = 'ansible-playbook -i %s ./install_controller.yml' % INVEN_FILE
    process_ansible(cmd)
    time.sleep(60)
    cmd = 'ansible-playbook -i %s ./controller_nova.yml' % INVEN_FILE
    process_ansible(cmd)
    time.sleep(60)
    cmd = 'ansible-playbook -i %s ./controller_netprovider.yml' % INVEN_FILE
    process_ansible(cmd)
    time.sleep(60)
    cmd = 'ansible-playbook -i %s ./compute_nova.yml' % INVEN_FILE
    process_ansible(cmd)
    time.sleep(60)
    cmd = 'ansible-playbook -i %s ./compute_netprovider.yml' % INVEN_FILE
    process_ansible(cmd)
    time.sleep(60)
    cmd = 'ansible-playbook -i %s ./operate.yml' % INVEN_FILE
    process_ansible(cmd)


def process_ansible(cmd):
    args = shlex.split(cmd)
    p = subprocess.Popen(args)
    out = p.communicate()
    logging.debug(out)


def generate_config(man_ip, com_ips):
    inventery = (
        '[controller]\n'
        '%s\n'
        '[compute]\n'
        '%s\n') % (man_ip, '\n'.join(com_ips))
    hosts = (
        '127.0.0.1   localhost localhost.localdomain localhost4 localhost4'
        '.localdomain4\n'
        '::1         localhost localhost.localdomain localhost6 localhost6'
        '.localdomain6\n')
    hosts = hosts + '%s controller\n' % man_ip
    for ind, com_ip in list(enumerate(com_ips)):
        hosts = hosts + '%s compute%s' % (com_ip, ind)

    with open(INVEN_FILE, 'wb') as inv_file:
        inv_file.write(inventery)
        inv_file.flush()
    with open(HOSTS_FILE, 'wb') as host_file:
        host_file.write(hosts)
        host_file.flush()


if __name__ == '__main__':
    main()
    print "Finish"
