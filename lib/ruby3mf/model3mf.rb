require_relative 'mesh_analyzer'

class Model3mf

  def self.parse(document, zip_entry)
    model_doc = nil

    Log3mf.context "parsing model" do |l|
      begin
        model_doc = GlobalXMLValidations.validate_parse(zip_entry)
      rescue Nokogiri::XML::SyntaxError => e
        l.fatal_error "Model file invalid XML. Exception #{e}"
      end

      l.context "verifying 3D payload required resources" do |l|
        # results = model_doc.css("model resources m:texture2d")
        required_resources = model_doc.css("//model//resources//*[path]").collect { |n| n["path"] }

        # for each, ensure that they exist in m.relationships
        relationship_resources = document.relationships.map { |relationship| relationship[:target] }

        missing_resources = (required_resources - relationship_resources)
        if missing_resources.empty?
          l.info "All model required resources are defined in .rels relationship files."
        else
          missing_resources.each { |mr|
            l.error :model_resource_not_in_rels, mr: mr
          }
        end

        l.context "verifying 3D resource types" do |l|
          model_types = model_doc.css("//model//resources//*[path]").collect { |t| t["contenttype"] }

          #for each, ensure they exist in ContentTypes
          all_types = document.types.map { |t, v| v }

          bad_types = (model_types - all_types)
          if bad_types.empty?
            l.info "All model resource contenttypes are valid"
          else
            bad_types.each { |bt|
              l.error :resource_contentype_invalid, bt: bt
            }
          end
        end

      end

      l.context "verifying model structure" do |l|
        root = model_doc.root
        if root.name != "model"
          l.error :root_3dmodel_element_not_model
        end
      end

      # call the analyzer
      MeshAnalyzer.validate(model_doc)
    end
    model_doc
  end
end
