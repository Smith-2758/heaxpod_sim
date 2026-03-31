import argparse
import sys
from coppeliasim_zmqremoteapi_client import RemoteAPIClient


def parse_bool(text: str) -> bool:
    return str(text).strip().lower() in {'1', 'true', 'yes', 'on'}


def main() -> int:
    parser = argparse.ArgumentParser(description='Ensure a temporary legacy remoteApi service is available via CoppeliaSim ZMQ API.')
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--rpc-port', type=int, default=23000)
    parser.add_argument('--legacy-port', type=int, required=True)
    parser.add_argument('--mode', choices=['ensure-temporary'], default='ensure-temporary')
    parser.add_argument('--pre-enable-trigger', default='true')
    args = parser.parse_args()

    client = RemoteAPIClient(args.host, args.rpc_port)
    sim_remote_api = client.getObject('simRemoteApi')
    pre_enable_trigger = parse_bool(args.pre_enable_trigger)

    if args.mode != 'ensure-temporary':
        raise ValueError(f'Unsupported mode: {args.mode}')
    if args.legacy_port <= 19999:
        raise ValueError('Temporary legacy remoteApi service ports must be > 19999.')

    try:
        before = sim_remote_api.status(args.legacy_port)
    except Exception:
        before = None
    sys.stdout.write(f'status_before={before}\n')

    try:
        sim_remote_api.stop(args.legacy_port)
    except Exception as exc:
        sys.stdout.write(f'stop_ignored={exc!r}\n')

    start_ret = sim_remote_api.start(args.legacy_port, 1300, False, pre_enable_trigger)
    after = sim_remote_api.status(args.legacy_port)
    sys.stdout.write(f'start_ret={start_ret}\n')
    sys.stdout.write(f'status_after={after}\n')

    if start_ret != 1 or after[0] != 1:
        raise RuntimeError(f'Failed to prepare temporary legacy remoteApi service on port {args.legacy_port}.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        sys.stderr.write(f'hexapod_legacy_remote_api_ctl error: {exc}\n')
        raise
