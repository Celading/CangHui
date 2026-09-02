// Generated-copy template. Product identity, permissions and business input stay consumer-owned.
export interface CangHuiSurfaceIngress {
  attach(nativeWindow: bigint, pixelWidth: number, pixelHeight: number, scaleMilli: number,
    generation: number): number;
  resize(pixelWidth: number, pixelHeight: number, scaleMilli: number, generation: number): number;
  frame(timestampNanos: bigint, targetTimestampNanos: bigint, generation: number): number;
  detach(generation: number): number;
}

export type CangHuiPointerPacket = {
  phase: 'down' | 'move' | 'up' | 'cancel'; x: number; y: number; pointerId: number;
  generation: number; source: 'mouse' | 'touch' | 'pen'; buttons: number; pressure: number;
  coordinateSpace: 'logicalViewport' | 'surfacePixel'; capturedScaleMilli: number;
  transformRevision: number; orientationRevision: number; sourceDeviceId: number;
  contactWidth: number; contactHeight: number; tiltX: number; tiltY: number; timestampNanos: bigint;
};

// Preserve the original consumer call shape while allowing newer hosts to attach richer
// device/contact metadata. Capture-owned scale and transform revisions are never trusted
// from the product layer; CangHui stamps them when the packet enters the mailbox.
export type CangHuiPointerInput = {
  phase: 'down' | 'move' | 'up' | 'cancel'; x: number; y: number; pointerId: number;
  source: 'mouse' | 'touch' | 'pen'; buttons: number; pressure: number;
  coordinateSpace?: 'logicalViewport' | 'surfacePixel'; sourceDeviceId?: number;
  contactWidth?: number; contactHeight?: number; tiltX?: number; tiltY?: number;
  timestampNanos?: bigint;
};

export type CangHuiKeyPacket = {
  phase: 'down' | 'up'; keyCode: number; scanCode: number; repeat: boolean;
  modifiers: number; generation: number;
};

export class CangHuiHostMailbox<T> {
  private readonly capacity: number;
  private values: T[] = [];
  constructor(capacity: number = 64) { this.capacity = Math.max(1, capacity); }
  push(value: T): void {
    if (this.values.length >= this.capacity) this.values.shift();
    this.values.push(value);
  }
  drain(): T[] { const result = this.values; this.values = []; return result; }
}

export class CangHuiXComponentHost {
  private generation: number = 0;
  private scaleMilli: number = 1000;
  private transformRevision: number = 0;
  private orientationRevision: number = 0;
  readonly pointerMailbox = new CangHuiHostMailbox<CangHuiPointerPacket>();
  readonly keyMailbox = new CangHuiHostMailbox<CangHuiKeyPacket>();
  constructor(private readonly ingress: CangHuiSurfaceIngress) {}
  onSurfaceCreated(nativeWindow: bigint, width: number, height: number, scaleMilli: number): number {
    this.generation += 1;
    this.scaleMilli = scaleMilli;
    this.transformRevision += 1;
    this.ingress.attach(nativeWindow, width, height, scaleMilli, this.generation);
    return this.generation;
  }
  onSurfaceChanged(width: number, height: number, scaleMilli: number): void {
    this.transformRevision += 1;
    this.scaleMilli = scaleMilli;
    this.ingress.resize(width, height, scaleMilli, this.generation);
  }
  onFrame(timestampNanos: bigint, targetTimestampNanos: bigint): void {
    this.ingress.frame(timestampNanos, targetTimestampNanos, this.generation);
  }
  onSurfaceDestroyed(): void { this.ingress.detach(this.generation); }
  onPointer(packet: CangHuiPointerInput): void {
    this.pointerMailbox.push({
      phase: packet.phase, x: packet.x, y: packet.y, pointerId: packet.pointerId,
      source: packet.source, buttons: packet.buttons, pressure: packet.pressure,
      coordinateSpace: packet.coordinateSpace ?? 'logicalViewport',
      sourceDeviceId: packet.sourceDeviceId ?? 0,
      contactWidth: packet.contactWidth ?? 0, contactHeight: packet.contactHeight ?? 0,
      tiltX: packet.tiltX ?? 0, tiltY: packet.tiltY ?? 0,
      timestampNanos: packet.timestampNanos ?? 0n, generation: this.generation,
      capturedScaleMilli: this.scaleMilli, transformRevision: this.transformRevision,
      orientationRevision: this.orientationRevision });
  }
  onOrientationRevision(revision: number): void {
    if (revision > this.orientationRevision) {
      this.orientationRevision = revision;
      this.transformRevision += 1;
    }
  }
  onKey(packet: Omit<CangHuiKeyPacket, 'generation'>): void {
    this.keyMailbox.push({ ...packet, generation: this.generation });
  }
  currentGeneration(): number { return this.generation; }
}
