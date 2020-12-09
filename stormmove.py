# dlau!
ticket_template="""

Parent maintenance required for %s.

Hello,

This ticket is concerning your instance: %s

The parent server that your instance is on requires maintenance. One of the redundant drives has failed an needs to be replaced. In an effort to limit the impact on your instance we will be moving it to a new parent. Your ip's and all your data will be retained.

We have scheduled this move to begin at %sEDT. If you would prefer a different time please let us know so that we may accommodate you. 

Your instance will remain online during most of this process. There will be one period of down time at the beginning of the move when the instance is rebooted and some file system maintenance is performed. While the length of the downtime period is usually only a few minutes we do not have a way to accurately predict how long it will actually take. We will monitor the move to ensure everything goes as smooth as possible for you. 

If you have any questions about this or would like to reschedule the move please let us know.
"""

import sys
from datetime import *

if sys.version_info >= (3,0):
    global raw_input
    raw_input = input

def yesno(**kwargs):
    message=kwargs.get('message', '(y/n)')
    rv = -1
    while rv == -1:
        user=raw_input(message)
        if user.lower() in ['y', 'yes' ]:
            rv = 1
        elif user.lower() in [ 'n', 'no']:
            rv = 0
        else: 
            print("try again");
            
    return rv	

class Instance:
    def __init__(self, hostname):
        self.hostname=hostname
        self.ticket=-1

class parent:
    def __init__(self,hostname, time, spacing, ticket):
        self.instances =[]
        self.hostname=hostname.strip()
        self.time=time
        self.ticket=ticket
        self.spacing=spacing

done = 0

def gimme_int(msg):
    good=0
    value=0
    while 1:
            value =raw_input(msg)
            try:
                value=int(value)
                return value
            except:
                print("A good value please.")
                continue

while done != 1 :
        hostname = raw_input("Parent hostname:").strip()
        leadtime = gimme_int("# days heads up:")
        spacing  = gimme_int("Hours between moves:")
        ticket=gimme_int("ticket number plz:")
        N=datetime.now().replace(minute=0,hour=18) + timedelta(days=leadtime,hours=1)
        print ("Moves will start on %s"%(N.strftime("%A, %B %d at %I:%M%p %Z")))
        print ("And occur every %d hours after that."%(spacing))
        if yesno(message="look good? (y/n)") == 1:
            done=1
            global Obj 
            Obj= parent(hostname,N,spacing,ticket)

while 1:
    instance = raw_input("instance hostname [empty to finish]:").strip()
    print("\n\n")
    if len(instance)==0:
            break
    print(ticket_template%(instance,instance, Obj.time.strftime("%A, %B %d at %I:%M%p %Z")))
    
    ticket_num=gimme_int("\n\nOpen the ticket and gimme the number!: ")
    i=Instance(instance)
    i.ticket=ticket_num
    i.time=Obj.time 
    Obj.instances.append(i)
    Obj.time=Obj.time + timedelta(hours=Obj.spacing)
    print("roger.\n")

print("Parent Hostname: %s"% Obj.hostname)
print("Parent ticket: #%d"% Obj.ticket)
print("Number of instances: %d" % len(Obj.instances))

for i in Obj.instances:
        print("\ninstance hostname: %s" %( i.hostname))
        print("instance ticket: #%d"% i.ticket)
        print("instance move date: %s" %(i.time.strftime("%B %d %I%p")))
