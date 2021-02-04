##################################################
##################################################
# Existing NSX objects to pull
##################################################
##################################################

data "nsxt_policy_transport_zone" "overlay_tz" {
    display_name         = var.nsx_vars.overlay_tz
}
 
data "nsxt_policy_transport_zone" "vlan_tz" {
    display_name         = var.nsx_vars.vlan_tz
}
 
data "nsxt_policy_edge_cluster" "edge_cluster" {
    display_name         = var.nsx_vars.edge_cluster
}

data "nsxt_policy_edge_node" "edge_node_first" {
    edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster.path
    display_name         = var.nsx_vars.edge_node_first
}

data "nsxt_policy_edge_node" "edge_node_second" {
    edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster.path
    display_name         = var.nsx_vars.edge_node_second
}

##################################################
##################################################
# Resources that will be created by Terraform
##################################################
##################################################

# VLAN segment (for Tier 0 Uplink)

resource "nsxt_policy_vlan_segment" "uplink_vlan" {
    display_name           = var.nsx_vars.vlan_uplink_segment_name
    description            = "Uplink of Tier0 provisioned by Terraform"
    vlan_ids               = [var.nsx_vars.vlan_uplink_segment_vlanid]
    transport_zone_path    = data.nsxt_policy_transport_zone.vlan_tz.path

    tag {
        scope = "demo"
        tag   = "tftest"
    }

}


# Tier 0 

resource "nsxt_policy_tier0_gateway" "tier0_new" {
    display_name              = var.nsx_vars.tier0_name
    description               = "Tier-0 provisioned by Terraform"
    failover_mode             = "NON_PREEMPTIVE"
    default_rule_logging      = false
    enable_firewall           = false
    #force_whitelisting        = true
    ha_mode                   = "ACTIVE_STANDBY"
    edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
 
    tag {
        scope = "demo"
        tag   = "tftest"
    }
}

# Attach VLAN segment to Tier0 on Edge Node First

resource "nsxt_policy_tier0_gateway_interface" "uplink1edgefirst" {
    display_name        = "Uplink1EdgeFirst"
    type                = "EXTERNAL"
    edge_node_path      = data.nsxt_policy_edge_node.edge_node_first.path
    gateway_path        = nsxt_policy_tier0_gateway.tier0_new.path
    segment_path        = nsxt_policy_vlan_segment.uplink_vlan.path
    subnets             = [var.nsx_vars.tier0_uplink_edge_node_first_ip]
    mtu                 = 1500

    tag {
        scope = "demo"
        tag   = "tftest"
    }

}

# Attach VLAN segment to Tier0 on Edge Node Second

resource "nsxt_policy_tier0_gateway_interface" "uplink1edgesecond" {
    display_name        = "Uplink1EdgeSecond"
    type                = "EXTERNAL"
    edge_node_path      = data.nsxt_policy_edge_node.edge_node_second.path
    gateway_path        = nsxt_policy_tier0_gateway.tier0_new.path
    segment_path        = nsxt_policy_vlan_segment.uplink_vlan.path
    subnets             = [var.nsx_vars.tier0_uplink_edge_node_second_ip]
    mtu                 = 1500

    tag {
        scope = "demo"
        tag   = "tftest"
    }

}

# Default static route on Tier 0

resource "nsxt_policy_static_route" "default_route" {
    display_name = "default"
    gateway_path = nsxt_policy_tier0_gateway.tier0_new.path
    network      = "0.0.0.0/0"

    next_hop {
        admin_distance = "1"
        ip_address     = var.nsx_vars.tier0_default_route_next_hop_ip
    }

    tag {
        scope = "demo"
        tag   = "tftest"
    }
}

# DHCP Server Profile for Tier 1

resource "nsxt_policy_dhcp_server" "tier1_dhcp" {
    display_name     = "DhcpServer"
    description      = "DHCP server for the Tier1"
    edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
    server_addresses = ["100.94.0.1/30"]
    # This DHCP server IP is locally significant for the Tier1

    tag {
        scope = "demo"
        tag   = "tftest"
    }
}


# Tier 1

resource "nsxt_policy_tier1_gateway" "tier1_new" {
    display_name                = var.nsx_vars.tier1_name
    description                 = "Tier-1 provisioned by Terraform"
    # edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
    # failover_mode             = "NON_PREEMPTIVE"
    # default_rule_logging      = "false"
    # enable_firewall           = "true"
    # enable_standby_relocation = "false"
    # force_whitelisting        = "true"
    dhcp_config_path            = nsxt_policy_dhcp_server.tier1_dhcp.path
    tier0_path                  = nsxt_policy_tier0_gateway.tier0_new.path
    route_advertisement_types   = ["TIER1_CONNECTED"]
 
    tag {
        scope = "demo"
        tag   = "tftest"
    }
 
    # route_advertisement_rule {
    #    name                      = "Tier 1 Networks"
    #    action                    = "PERMIT"
    #    subnets                   = ["10.10.10.0/24", "10.20.20.0/24"]
    #    prefix_operator           = "GE"
    #    route_advertisement_types = ["TIER1_CONNECTED"]
    #}
}

# Segment 1 on Tier 1 (with DHCP enabled)

resource "nsxt_policy_segment" "tier1_segment1" {
    display_name        = var.nsx_vars.tier1_segment1_name
    description         = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_new.path

    tag {
        scope = "demo"
        tag   = "tftest"
    }
 
    subnet {   
        cidr        = var.nsx_vars.tier1_segment1_ip
        dhcp_ranges = [var.nsx_vars.tier1_segment1_dhcp_range] 
     
   
        dhcp_v4_config {
             lease_time  = 36000
             dns_servers = [var.nsx_vars.tier1_segment1_dns_server_ip]
        }
    }
}

resource "null_resource" "ubuntu" {

  connection {
    type = "ssh"
	  agent = "false"
	  host = "10.79.1.8"
      
	  user = "vmware"
	  password = "VMware1!"
  }

  provisioner "remote-exec" {

    inline = ["echo VMware1! | sudo -S route add -net 10.20.20.0/24 gw 10.79.1.10"]
  }

  provisioner "remote-exec" {

    when = destroy
    inline = ["echo VMware1! | sudo -S route delete -net 10.20.20.0/24"]
  }

}
