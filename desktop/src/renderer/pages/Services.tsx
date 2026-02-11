import { useServices, useServiceChannel } from '../hooks/useServices';
import { ServiceCard } from '../components/services/ServiceCard';

export function Services() {
  const { services, start, stop } = useServices();
  useServiceChannel();

  return (
    <div className="space-y-6">
      <p className="text-sm text-muted-foreground">
        Managed services for your development environment.
      </p>

      {services.length === 0 ? (
        <div className="rounded-lg border border-border bg-card p-12 text-center">
          <p className="text-muted-foreground">
            No services available. Make sure the daemon is running.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {services.map((service) => (
            <ServiceCard
              key={service.name}
              service={service}
              onStart={start}
              onStop={stop}
            />
          ))}
        </div>
      )}
    </div>
  );
}
