import multiprocessing

bind = '0.0.0.0:8000'

workers = 2

threads = 4

worker_class = 'gevent'

worker_connections = 1000

proc_name = 'gunicorn'

loglevel = "info"                         # 日志级别
